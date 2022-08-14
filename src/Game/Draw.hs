module Game.Draw where

import Control.Lens
import Control.Monad.RWS

import Game.Action
import Game.AssetManagement
import Game.Data.Alias
import Game.Data.Asset
import Game.Data.Environment
import Game.Data.State
import Game.Logic
import Game.Data.Enum

import Graphics.Gloss

renderGame :: RWSIO Picture
renderGame = do
    env <- ask

    -- level cell/tiles pictures
    level        <- use (gLevelState . lLevelCells)
    layerBack    <- drawTiles "*tb"
    layerFront   <- drawTiles "^kc"
    
    -- player picture
    (x, y)       <- use (gPlayerState . pPosition)
    playerSprite <- getPlayerSprite
    let playerPos = (x, y - 4) -- offset
        playerPic = [uncurry translate playerPos playerSprite]
    
    -- bg & text pictures
    background   <- renderBackground
    text         <- renderText
    timer        <- renderTimer
    
    -- title pictures
    titlePic     <- scaleTitle
    levelName    <- use (gLevelState . lLevelName)
    transition   <- use gTransition
    let tX            = 256 * min 0 transition
        posTitle      = ( tX,  32)
        posSubtitle   = (-tX, -64)
        lvlTitles = view (eAssets . aLvlTitles   ) env
        lvlSubs   = view (eAssets . aLvlSubtitles) env
        (w, h)    = (view eWindowWidth env, view eWindowHeight env)
        lvlTitle  = if tX < -fromIntegral w then []
            else case lookup levelName lvlTitles of
            Just title -> [uncurry translate posTitle title]
            Nothing    -> []
        lvlSub    = if tX < -fromIntegral h then []
            else case lookup levelName lvlSubs of
            Just sub   -> [uncurry translate posSubtitle sub]
            Nothing    -> []
    
    scene <- use gGameScene
    return . pictures $ case scene of 
        ScenePause     ->
            background ++
            layerBack  ++
            playerPic  ++ 
            layerFront ++
            text
        SceneStart     ->
            background ++ 
            titlePic   ++
            text
        SceneCredits   ->
            background ++ 
            text
        SceneLevel     ->
            if transition < 0
                then
                    background ++
                    lvlTitle   ++
                    lvlSub     ++
                    layerBack  ++
                    playerPic  ++
                    layerFront ++
                    text       ++
                    timer
                else
                    background ++
                    layerBack  ++
                    playerPic  ++
                    layerFront ++
                    lvlTitle   ++
                    lvlSub     ++
                    text       ++
                    timer
        SceneWin       ->
            background ++ 
            -- tiles ++
            text
        SceneLose      ->
            background ++
            -- tiles ++
            text
        
    

updateGame :: Float -> RWSIO GameState
updateGame sec = do
    gDeltaSec .= sec -- might need this for other screen states
                     -- normally, the value should be 1/FPS
    timeRemaining  <- use gTimeRemaining
    gTimeRemaining .= timeRemaining - sec
    
    scene <- use gGameScene
    case scene of
        ScenePause -> 
            return () -- update nothing
        SceneLevel -> do
            movePlayer
            incPlayerSprite
            -- ALUT
            -- playSFX
            -- ENDALUT
            
            keys <- incKeys
            gPlayerState . pCollectedKeys .= keys
            
            updatedLevel  <- removeItem
            gLevelState . lLevelCells .= updatedLevel
            
            door <- openDoor
            gDoorOpen .= door
            
            checkDoor
            updateParallax
            updateTransition
    get --  return GameState

-- Helper Functions:
renderTile :: (PureRWS m) => CellType -> m Picture
renderTile cellType = do
    env <- ask
    let baseImg  = view (eAssets . aBase ) env
        grassImg = view (eAssets . aGrass) env
        coinImg  = head $ view (eAssets . aCoin) env
        keyImg   = view (eAssets . aKey  ) env
        doorImgs = view (eAssets . aDoor ) env
    
    isDoorOpen <- use gDoorOpen
    doorTup    <- getDoorSprite
    
    return $ case cellType of
        '*' -> baseImg 
        '^' -> grassImg
        'c' -> coinImg
        'k' -> fst keyImg
        't' -> fst doorTup
        'b' -> snd doorTup
        _   -> circle 0 -- should never reach here
    

drawTiles :: (PureRWS m) => [CellType] -> m [Picture]
drawTiles cellTypes = do
    level <- use (gLevelState . lLevelCells)
    let  tiles = filter ((`elem` cellTypes) . snd) level
    forM tiles (\ (pos, cell) -> do
        tile  <- renderTile cell
        return . uncurry translate pos $ tile)
    

renderText :: (PureRWS m) => m [Picture]
renderText = do
    env          <- ask
    scene        <- use gGameScene
    level        <- use (gLevelState . lLevelName)
    let continue  = view (eAssets . aTxtPause) env
    let title     = view (eAssets . aTxtTitle) env
    let enter     = view (eAssets . aTxtEnter) env
    let startText = [uncurry translate (0,-200) enter] 

    case scene of
        ScenePause  -> case level of
                    LevelStart  -> return startText --Add credits screen?
                    _           -> return [continue]
        _           -> case level of
                    LevelStart  -> return startText 
                    _           -> return []

--Will fix up numbers 
scaleTitle :: (PureRWS m) => m [Picture]
scaleTitle = do
    env <- ask
    timeRemaining <- use gTimeRemaining
    let delta = (120 - timeRemaining) * 2
    let fps = view (eFPS) env
    let title  = view (eAssets . aTxtTitle) env
    let newDelta =  if delta >= 10
                    then 10
                    else delta
    let scaleXY = newDelta / 10
    let pic = scale scaleXY scaleXY $ uncurry translate (0,100) title
    return [pic]

renderBackground :: (PureRWS m) => m [Picture]
renderBackground = do
    env   <- ask
    level <- use (gLevelState . lLevelName)
    scene <- use (gGameScene)   
    
    let lvlList  = view (eAssets . aLvlNames) env
        bgImgs   = view (eAssets . aBgImg   ) env
        zipLvls  = zip lvlList bgImgs
        imgToUse = lookup (show level) zipLvls
    
    parallax <- use gParallax
    case imgToUse of
        Just bg -> return [uncurry translate parallax bg]
        Nothing -> return []
    

updateParallax :: (PureRWS m) => m ()
updateParallax = do
    d      <- use gDeltaSec
    (x, y) <- use (gPlayerState . pPosition)
    
    let smooth a b = a + 5 * d * signum c * abs c where c = b - a
        moveTo (x1, y1) (x2, y2) = (smooth x1 x2, smooth y1 y2)
        target = (-x/5, -y/25)
    gParallax %= (`moveTo` target)

updateTransition :: (PureRWS m) => m ()
updateTransition = do
    sec <- use gDeltaSec
    gTransition %= (+negate sec)

renderDigits :: String -> [Picture] -> [Picture]
renderDigits [] _ = []
renderDigits (x:xs) digits 
            | x == '-'  = [digits !! 0]                               -- keep showing 0 when timer goes negative
            | otherwise = digits !! read [x] : renderDigits xs digits

addShift :: [Picture] -> Float -> Float -> [Picture]
addShift [] _ _ = []  -- 30 is width of digit picture
addShift (x:xs) xPos yPos = (uncurry translate (xPos - fromIntegral (30 * length xs), yPos) x) : (addShift xs xPos yPos)

renderTimer :: (PureRWS m) => m [Picture]
renderTimer = do
    env <- ask
    timeRemaining <- use gTimeRemaining
    let timerText = show . round $ timeRemaining
    let windowWidth = view eWindowWidth env
    let windowHeight = view eWindowHeight env
    let tileSize     = view eTileSize env
    let digits = view (eAssets . aTxtDigits) env
    let timerPics = renderDigits timerText digits
    let xPos = fromIntegral windowWidth / 2  - tileSize / 2
    let yPos = fromIntegral windowHeight / 2 - tileSize / 2
    let timer = addShift timerPics xPos yPos
    return timer

-- ALUT
-- playSFX :: RWSIO ()
-- playSFX = do
--     player <- use (gPlayerState . pPosition)
--     let coin = getCoinCellType
--         key  = getKeyCellType
--         door = getDoorCellType
    
--     hitCoin <- collideWith coin player
--     case hitCoin of
--         Just cn -> playSound Coin
--         Nothing -> return ()
    
--     hitKey <- collideWith key player
--     case hitKey of
--         Just ky -> playSound Key
--         Nothing -> return ()
    
--     hitDoor <- collideWith door player
--     isDoorOpen <- use gDoorOpen
--     when isDoorOpen $ case hitDoor of
--         Just dr -> playSound DoorClose
--         Nothing -> return ()
-- ENDALUT
