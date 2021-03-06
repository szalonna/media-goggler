module MediaGoggler.API where

import Conduit (ConduitT, ResourceT)
import Protolude
import Servant

import qualified Data.ByteString.Lazy as BL
import qualified Network.HTTP.Media as M

import MediaGoggler.DBEntry (DBEntry)
import MediaGoggler.Datatypes (Library, Person, Id, Movie, VideoFile)

type SimpleGet res = Get '[JSON] (DBEntry res)

type GetAll res = QueryParam "count" Int :> Get '[JSON] [DBEntry res]
type PostSingle res = ReqBody '[JSON] res :> Post '[JSON] (DBEntry res)
type GetSingle res = Capture "id" Id :> Get '[JSON] (DBEntry res)

type Endpoint res = GetAll res :<|> PostSingle res
type SimpleEndpoint res = GetSingle res :<|> Endpoint res

type MediaGogglerAPI = "libraries" :> (LibraryAPI :<|> Endpoint Library)
    :<|> "persons" :> SimpleEndpoint Person
    :<|> "movies" :> MovieAPI
    :<|> "files" :> FileAPI

type LibraryAPI = Capture "id" Id :> (
        SimpleGet Library
        :<|> "movies" :> Endpoint Movie
    )

type MovieAPI = Capture "id" Id :> (
        Get '[JSON] (DBEntry Movie)
        :<|> "files" :> Endpoint VideoFile
    )

type FileStream = ConduitT () ByteString (ResourceT IO) ()
type VideoStream n = Stream 'GET n NoFraming OggVideo (
        Headers '[
                Header "Accept-Ranges" Text,
                Header "Content-Length" Int64,
                Header "Content-Range" Text
            ] FileStream
    )

type FileAPI = Capture "id" Id :> (
        Get '[JSON] (DBEntry VideoFile)
        :<|> "raw" :> (
                Header "Range" Text :> VideoStream 206
                :<|> VideoStream 200
            )
    )

data OggVideo deriving Typeable

instance Accept OggVideo where
    contentType _ = "video" M.// "ogg"

instance MimeRender OggVideo ByteString where
    mimeRender _ = BL.fromStrict
