{-# LANGUAGE FlexibleContexts #-}

module Game.Input where

import Control.Lens
import Control.Monad.RWS
import Control.Lens

import Game.Action
import Game.AssetManagement
import Game.Data.Enum
import Game.Data.Environment
import Game.Data.State
import Game.Logic

import Graphics.Gloss.Interface.IO.Game

--TODO: Add text "Press 'p' to continue" or similar. t

handleKeys :: Event -> RWST Environment [String] GameState IO GameState
handleKeys e = do
    isPaused <- use gPaused
    heading  <- use (gPlayerState . pHeading)
    case e of
        (EventKey (Char 'p') Down _ _) -> do
            pauseGame
            case heading of
                FaceRight -> stopMoveRight
                FaceLeft  -> stopMoveLeft
        _                              ->
            case isPaused of
                True -> return ()
                False -> case e of 
                        (EventKey (SpecialKey KeyLeft) Down _ _)  -> 
                            moveLeft
                        (EventKey (SpecialKey KeyRight) Down _ _) -> 
                            moveRight
                        (EventKey (SpecialKey KeyUp) Down _ _)    -> 
                            moveUp
                        (EventKey (SpecialKey KeyLeft) Up _ _)    -> 
                            stopMoveLeft
                        (EventKey (SpecialKey KeyRight) Up _ _)   -> 
                            stopMoveRight
                        _                                         ->
                            return ()
    newState <- get
    return newState

pauseGame :: (MonadRWS Environment [String] GameState m) => m ()
pauseGame = do
    isPaused <- use gPaused
    case isPaused of
        False -> gPaused .= True
        True -> gPaused .= False

moveUp :: (MonadRWS Environment [String] GameState m) => m ()
moveUp = do
    env <- ask
    let tileSize = view eTileSize env
    
    (x, y) <- use (gPlayerState . pPosition)
    let colliders = getCollidables
    
    hit <- collideWith colliders (x, y - tileSize)
    case hit of
        Nothing -> return ()
        Just _  -> do
            (currSpeedX, _) <- use (gPlayerState . pSpeed)
            gPlayerState . pSpeed .= (currSpeedX , 2000)
        
    

moveLeft :: (MonadRWS Environment [String] GameState m) => m ()
moveLeft = do
    gPlayerState . pMovement .= MoveLeft
    gPlayerState . pHeading  .= FaceLeft

moveRight :: (MonadRWS Environment [String] GameState m) => m () 
moveRight = do
    gPlayerState . pMovement .= MoveRight
    gPlayerState . pHeading  .= FaceRight 

stopMoveLeft :: (MonadRWS Environment [String] GameState m) => m () 
stopMoveLeft = do
    movement <- use (gPlayerState . pMovement)
    case movement of
        MoveLeft -> gPlayerState . pMovement .= MoveStop
        _        -> return ()
    

stopMoveRight :: (MonadRWS Environment [String] GameState m) => m () 
stopMoveRight = do
    movement <- use (gPlayerState . pMovement)
    case movement of
        MoveRight -> gPlayerState . pMovement .= MoveStop
        _         -> return ()
    

-- exitGame??
