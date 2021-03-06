{-# LANGUAGE OverloadedStrings, ViewPatterns #-}

module Quark.Cursor ( ixToCursor
                    , cursorToIx
                    , distance
                    , move ) where

import Data.ByteString.UTF8 (ByteString)
import qualified Data.ByteString.UTF8 as U
import qualified Data.ByteString.Char8 as B

import Quark.Types ( Cursor
                   , Index
                   , Direction ( Backward
                               , Forward
                               , Up
                               , Down ) )
import Quark.Helpers ( nlTail
                     , strHeight
                     , tabbedLength
                     , (~~) )
import Quark.Settings ( tabWidth )

-- Convert a linear index of a string to a cursor
ixToCursor :: Index -> ByteString -> Cursor
ixToCursor ix s = (row, col)
  where
    row = (length s0Lines) - 1
    col = (tabbedLength tabWidth $ last s0Lines) - 1
    s0Lines = U.lines $ s0 ~~ " "
    (s0, _) = U.splitAt ix s

-- Convert a cursor on a string to a linear index
cursorToIx :: Cursor -> ByteString -> Index
cursorToIx _ "" = 0
cursorToIx (0, col) xs = loop (0, 0, col) xs
  where
    loop (n, k, col') xs
        | col' <= 0 = n
        | otherwise =
              case U.decode xs of
                  Just ('\n', _) -> n
                  Just ('\t', m) -> loop (n + nAdd, k + kk, col' - kk) (B.drop m xs)
                    where
                      kk = tabWidth - mod k tabWidth
                      nAdd = if col' >= kk then 1 else 0
                  Just (_, m)    -> loop (n + 1, k + 1, col' - 1) (B.drop m xs)
                  Nothing        -> n
cursorToIx (row, col) (U.uncons -> Just (x, xs))
    | row < 0   = 0
    | x == '\n' = 1 + cursorToIx (row - 1, col) xs
    | otherwise = 1 + cursorToIx (row, col) xs

-- Compute distance between two cursors on a string (may be negative)
distance :: Cursor -> Cursor -> ByteString -> Int
distance crs0 crs1 s = (cursorToIx crs1 s) - (cursorToIx crs0 s)

-- Move a cursor on a string
move :: Direction -> ByteString -> Cursor -> Cursor
move Backward s crs = ixToCursor (max ((cursorToIx crs s) - 1) 0) s
move Forward s crs = ixToCursor (min ((cursorToIx crs s) + 1) (U.length s)) s
move Up _ (row, col) = (max (row - 1) 0, col)
move Down s (row, col) = (min (row + 1) $ strHeight s - 1, col)