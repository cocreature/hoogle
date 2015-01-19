{-# LANGUAGE ViewPatterns, TupleSections, RecordWildCards, ScopedTypeVariables, PatternGuards #-}

module Output.Items(writeItems, lookupItem) where

import Language.Haskell.Exts
import Control.Applicative
import System.IO.Extra
import Data.List.Extra
import System.FilePath
import Control.Monad
import Control.DeepSeq

import Input.Type


writeItems :: FilePath -> [ItemEx] -> IO [(Maybe Id, Item)]
writeItems file xs = withBinaryFile (file <.> "items") WriteMode $ \h -> do
    forM xs $ \x -> case x of
        ItemEx{..} | Just s <- f itemItem -> do
            i <- Id . fromIntegral <$> hTell h
            hPutStrLn h $ show i ++ " " ++ s
            hPutStrLn h itemURL
            hPutStrLn h $ intercalate ", " $ for itemParents $ \xs -> unwords ["<a href=\"" ++ b ++ "\">" ++ a ++ "</a>" | (a,b) <- xs]
            hPutStrLn h $ unlines $ replace [""] ["."] $ lines itemDocs
            return $ (Just i, itemItem)
        ItemEx{..} -> return (Nothing, itemItem)
    -- write all the URLs, docs and enough info to pretty print it to a result
    -- and replace each with an identifier (index in the space) - big reduction in memory
    where
        f :: Item -> Maybe String
        f (IDecl i@InstDecl{}) = rnf (show i) `seq` Nothing
        f x = rnf (show x) `seq` Just (showItem x)


lookupItem :: Database -> Id -> IO [String]
lookupItem (Database file) (Id i) = withBinaryFile (file <.> "items") ReadMode $ \h -> do
    hSeek h AbsoluteSeek $ fromIntegral i
    xs <- replicateM 3 $ hGetLine h
    (xs ++) <$> f h
    where
        f h = do
            s <- hGetLine h
            if s == "" then return [] else (s:) <$> f h
