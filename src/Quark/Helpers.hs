{-# LANGUAGE OverloadedStrings #-}

module Quark.Helpers where

import Data.ByteString.UTF8 (ByteString)
import qualified Data.ByteString.UTF8 as U
import qualified Data.ByteString.Char8 as B

import System.FilePath ( splitPath
                       , joinPath )

import Quark.Types ( Size
                   , Index )

-- ByteString version of (++)
(~~) :: B.ByteString -> B.ByteString -> B.ByteString
(~~) = B.append

-- XNOR
xnor :: Bool -> Bool -> Bool
xnor a b = (a && b) || (not a && not b)

-- Order two things, smallest first
orderTwo :: Ord a => a -> a -> (a, a)
orderTwo x y = case compare x y of
    GT -> (y, x)
    _  -> (x, y)

-- Compute width of a string in number of columns
strWidth :: ByteString -> Int
strWidth s = maximum $ map U.length $ U.lines s

-- Compute height of a string in number of rows
strHeight :: ByteString -> Int
strHeight s = length $ U.lines $ s ~~ " "

-- Compute size of a string (height and width)
strSize :: ByteString -> Size
strSize s = (strHeight s, strWidth s)

-- Line number width
lnWidth :: ByteString -> Int
lnWidth s =
    (length $ show $ (length $ U.lines s) + if nlTail s then 1 else 0) + 1

lnIndent :: Char -> Int -> ByteString -> Int
lnIndent c r s = case drop r (U.lines s) of
    (x:_) -> U.length $ B.takeWhile (\c' -> c' == c) x
    _     -> 0

lnIndent' :: Int -> ByteString -> ByteString
lnIndent' r s = case drop r (U.lines s) of
    (x:_) -> B.takeWhile (\c -> c == ' ' || c == '\t') x
    _     -> ""

lineSplitIx :: Int -> ByteString -> Int
lineSplitIx r s = min (U.length s) $ U.length $ B.unlines $ take r $ U.lines s

-- Check is a string ends in newline or not
nlTail :: ByteString -> Bool
nlTail "" = False
nlTail s  = if B.last s == '\n' then True else False

-- Pad a string with spaces at the end
padToLen :: Int -> ByteString -> ByteString
padToLen k a
    | k <= U.length a = a
    | otherwise       = padToLen k $ a ~~ " "

padToLen' :: Int -> ByteString -> ByteString
padToLen' k a
    | k <= U.length a = a
    | otherwise       = padToLen k (B.cons ' ' a)

-- Concatenate two strings, padding with spaces in the middle
padMidToLen :: Int -> String -> String -> String
padMidToLen k a0 a1
    | k >= (length a0 + length a1) = a0 ++ a1
    | otherwise                    = padMidToLen k (a0 ++ " ") a1

fixToLenPadMid :: Int -> [a] -> [a] -> a -> [a]
fixToLenPadMid k xs ys z
    | k <= 0      = []
    | nx > k      = take k xs
    | nx + ny > k = xs ++ take (k - nx) ys
    | otherwise   = fixToLenPadMid k xs (z:ys) z
  where
    nx = length xs
    ny = length ys

trimPathHead :: Int -> FilePath -> FilePath
trimPathHead k p
    | k <= 0        = ""
    | k >= length p = p
    | otherwise     = ".../" ++ (joinPath $
          dropWhile' (\x -> (length $ concat x) > (k - 4)) $ splitPath p)

dropWhile' :: ([a] -> Bool) -> [a] -> [a]
dropWhile' _ [] = []
dropWhile' f xs = if f xs then dropWhile' f (drop 1 xs) else xs

-- Selection helpers
splitAt2 :: (Int, Int) -> ByteString -> (ByteString, ByteString, ByteString)
splitAt2 (k0, k1) l = (x, y, z)
  where
    (x, x') = U.splitAt k0 l
    (y, z) = U.splitAt (k1 - k0) x'

selectionLines :: (ByteString, ByteString, ByteString) -> [[(ByteString, Bool)]]
selectionLines (x, y, z) = case (nlTail x, nlTail y) of
    (True, True)   -> concat [lx, ly, lz]
    (True, False)  -> concat [lx, fuseSL ly lz]
    (False, True)  -> concat [fuseSL lx ly, lz]
    (False, False) -> fuseSL (fuseSL lx ly) lz
  where
    lx = [[(s, False)] | s <- U.lines x]
    ly = [[(s, True)] | s <- U.lines y]
    lz = [[(s, False)] | s <- U.lines z]
    fuseSL ps [] = ps
    fuseSL [] qs = qs
    fuseSL ps (q:qs) = ps' ++ (concat [p, q]):qs
      where
        (ps', [p]) = splitAt (length ps - 1) ps

dropSL :: Int -> [(ByteString, Bool)] -> [(ByteString, Bool)]
dropSL _ [] = []
dropSL k x@((p, q):xs)
    | k <= 0    = x
    | otherwise = case k < n of True  -> (U.drop k p, q):xs
                                False -> dropSL (k - n) xs
  where
    n = U.length p

padToLenSL :: Int -> [(ByteString, Bool)] -> [(ByteString, Bool)]
padToLenSL k [] = [(B.replicate k ' ', False)]
padToLenSL k (x@(p0, _):xs) = x:(padToLenSL (k - U.length p0) xs)

tabbedLength :: Int -> ByteString -> Int
tabbedLength tabWidth b = loop (0, 0) b
  where
    loop (n, nLine) xs =
        case U.decode xs of
            Just ('\n', m) -> loop (n + 1, 0) (B.drop m xs)
            Just ('\t', m) -> loop (n + nn, nLine + nn) (B.drop m xs)
              where
                nn = tabWidth * (div (nLine + tabWidth) tabWidth) - nLine
            Just (_, m)    -> loop (n + 1, nLine + 1) (B.drop m xs)
            Nothing        -> n

fixTo :: Int -> String -> String
fixTo k s = padToLenWith k ' ' $ take k s

padToLenWith :: Int -> a -> [a] -> [a]
padToLenWith k p x
    | k <= length x = x
    | otherwise     = padToLenWith k p (x ++ [p])

zip4 :: [a] -> [b] -> [c] -> [d] -> [(a, b, c, d)]
zip4 (a:as') (b:bs) (c:cs) (d:ds) = (a, b, c, d):(zip4 as' bs cs ds)
zip4 _       _      _      _      = []

findIx :: Index -> Bool -> ByteString -> ByteString -> Index
findIx _ _ findString s
    | B.isInfixOf findString s == False = (-1)
findIx k True findString s
    | s0b == "" && s1b == "" = k - 1
    | s1b == "" = U.length s0a
    | otherwise = U.length s0 + U.length s1a
  where
    (s0a, s0b) = B.breakSubstring findString s0
    (s1a, s1b) = B.breakSubstring findString s1
    (s0, s1) = U.splitAt k s
findIx k False findString s = if s0b == ""
                                  then U.length s0 + lastIx s1
                                  else lastIx s0
  where
    (s0a, s0b) = B.breakSubstring findString s0
    (s0, s1) = U.splitAt k s
    lastIx s' = case B.breakSubstring findString s' of
        (s'', "")  -> (-1)
        (s0', s1') -> U.length s0' + 1 + (lastIx $ U.drop 1 s1')