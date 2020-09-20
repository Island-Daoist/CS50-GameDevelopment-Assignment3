--[[
    GD50
    Match-3 Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    State in which we can actually play, moving around a grid cursor that
    can swap two tiles; when two tiles make a legal swap (a swap that results
    in a valid match), perform the swap and destroy all matched tiles, adding
    their values to the player's point score. The player can continue playing
    until they exceed the number of points needed to get to the next level
    or until the time runs out, at which point they are brought back to the
    main menu or the score entry menu if they made the top 10.
]]

PlayState = Class{__includes = BaseState}

function PlayState:init()
    
    -- start our transition alpha at full, so we fade in
    self.transitionAlpha = 1

    -- position in the grid which we're highlighting
    self.boardHighlightX = 0
    self.boardHighlightY = 0

    -- timer used to switch the highlight rect's color
    self.rectHighlighted = false

    -- flag to show whether we're able to process input (not swapping or clearing)
    self.canInput = true

    -- tile we're currently highlighting (preparing to swap)
    self.highlightedTile = nil

    self.score = 0
    self.timer = 60

    -- set our Timer class to turn cursor highlight on and off
    Timer.every(0.5, function()
        self.rectHighlighted = not self.rectHighlighted
    end)

    -- subtract 1 from timer every second
    Timer.every(1, function()
        self.timer = self.timer - 1

        -- play warning sound on timer if we get low
        if self.timer <= 5 then
            gSounds['clock']:play()
        end
    end)
end

function PlayState:enter(params)
    
    -- grab level # from the params we're passed
    self.level = params.level

    -- spawn a board and place it toward the right
    self.board = params.board or Board(VIRTUAL_WIDTH - 272, 16, self.level)

    -- create a variable to hold a copy of the board to be used for validation
    self.boardCopy = Board(VIRTUAL_WIDTH - 272, 16, self.level)

    -- grab score from params if it was passed
    self.score = params.score or 0

    -- score we have to reach to get to the next level
    self.scoreGoal = self.level * 1.25 * 1000
end

function PlayState:update(dt)
    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end

    -- go back to start if time runs out
    if self.timer <= 0 then
        
        -- clear timers from prior PlayStates
        Timer.clear()
        
        gSounds['game-over']:play()

        gStateMachine:change('game-over', {
            score = self.score
        })
    end

    -- go to next level if we surpass score goal
    if self.score >= self.scoreGoal then
        
        -- clear timers from prior PlayStates
        -- always clear before you change state, else next state's timers
        -- will also clear!
        Timer.clear()

        gSounds['next-level']:play()

        -- change to begin game state with new level (incremented)
        gStateMachine:change('begin-game', {
            level = self.level + 1,
            score = self.score
        })
    end
    
    -- validate board as valid
    local boardValid = self:validateBoard()
    if boardValid then
      -- store mouse position to use for selecting and swaping tiles
      local mouseX, mouseY = push:toGame(love.mouse.getPosition())

      if self.canInput then
          -- move cursor around based on bounds of grid, playing sounds
          if love.keyboard.wasPressed('up') then
              self.boardHighlightY = math.max(0, self.boardHighlightY - 1)
              gSounds['select']:play()
          elseif love.keyboard.wasPressed('down') then
              self.boardHighlightY = math.min(7, self.boardHighlightY + 1)
              gSounds['select']:play()
          elseif love.keyboard.wasPressed('left') then
              self.boardHighlightX = math.max(0, self.boardHighlightX - 1)
              gSounds['select']:play()
          elseif love.keyboard.wasPressed('right') then
              self.boardHighlightX = math.min(7, self.boardHighlightX + 1)
              gSounds['select']:play()
          elseif validateMouseInput(mouseX, mouseY, VIRTUAL_WIDTH - 272,
            496, 16, 272) then
              if self.boardHighlightX == math.floor((mouseX - 240) / 32) and
                self.boardHighlightY == math.floor((mouseY - 16) / 32) then
                  ::continue::
              else
                self.boardHighlightX = math.floor((mouseX - 240) / 32)
                self.boardHighlightY = math.floor((mouseY - 16) / 32)
                gSounds['select']:play()
              end
         end
          
          -- add functionality to check board for possible matches. If no possible move can result in a match shuffle board
          -- then implement the funcionality to allow moves only if the result is a match
          -- may want to simulate moves in all four possible directions for each tile and see if a true result is returned

          -- if we've pressed enter, to select or deselect a tile...
          if love.keyboard.wasPressed('enter') or love.keyboard.wasPressed('return') or love.mouse.wasPressed(1) then
              -- if same tile as currently highlighted, deselect
              local x = self.boardHighlightX + 1
              local y = self.boardHighlightY + 1
              
              -- if nothing is highlighted, highlight current tile
              if not self.highlightedTile then
                  self.highlightedTile = self.board.tiles[y][x]

              -- if we select the position already highlighted, remove highlight
              elseif self.highlightedTile == self.board.tiles[y][x] then
                  self.highlightedTile = nil

              -- if the difference between X and Y combined of this highlighted tile
              -- vs the previous is not equal to 1, also remove highlight
              elseif math.abs(self.highlightedTile.gridX - x) + math.abs(self.highlightedTile.gridY - y) > 1 then
                  gSounds['error']:play()
                  self.highlightedTile = nil
              else                    
                  -- swap grid positions of tiles
                  newTile = self:performSwap(self.board, self.highlightedTile, y, x)
                  
                  if self.board:calculateMatches() then
                    -- tween coordinates between the two so they swap
                    Timer.tween(0.1, {
                        [self.highlightedTile] = {x = newTile.x, y = newTile.y},
                        [newTile] = {x = self.highlightedTile.x, y = self.highlightedTile.y}
                    })
                    
                    -- once the swap is finished, we can tween falling blocks as needed
                    :finish(function()
                        self:calculateMatches()
                    end)
                  else
                    self:performSwap(self.board, self.highlightedTile, newTile.gridY, newTile.gridX)
                    gSounds['error']:play()
                    self.highlightedTile = nil
                  end
              end
          end
      end
    else
      -- once the tiles are moved we can reset the board
      --[[local first_tween, second_tween = self.board:shuffleTiles()
      if first_tween and second_tween then
        Timer.tween(3, first_tween)
        Timer.tween(3, second_tween)
      end]]
      local tweenToCenter, tweenReset = self.board:getShuffleTweens()
      Timer.tween(0.5, tweenToCenter)
      :finish(function()
        if self.board:shuffleTiles() then
          Timer.tween(0.5, tweenReset)
        end
      end)
    end

    Timer.update(dt)
    
    self.board:update(dt)
    
end

--[[
    Calculates whether any matches were found on the board and tweens the needed
    tiles to their new destinations if so. Also removes tiles from the board that
    have matched and replaces them with new randomized tiles, deferring most of this
    to the Board class.
]]
function PlayState:calculateMatches()
    self.highlightedTile = nil

    -- if we have any matches, remove them and tween the falling blocks that result
    local matches = self.board:calculateMatches()
    
    if matches then
        gSounds['match']:stop()
        gSounds['match']:play()

        -- add score for each match
        for k, match in pairs(matches) do
            self.score = self.score + (#match * 50) + (match[1].variety * 125)
            self.timer = self.timer + #match
        end

        -- remove any tiles that matched from the board, making empty spaces
        self.board:removeMatches()

        -- gets a table with tween values for tiles that should now fall
        local tilesToFall = self.board:getFallingTiles()

        -- tween new tiles that spawn from the ceiling over 0.25s to fill in
        -- the new upper gaps that exist
        Timer.tween(0.25, tilesToFall):finish(function()
            
            -- recursively call function in case new matches have been created
            -- as a result of falling blocks once new blocks have finished falling
            self:calculateMatches()
        end)
    
    -- if no matches, we can continue playing
    else
        self.canInput = true
    end
end


function PlayState:performSwap(board, swapTile, y, x)  
  local tempX = swapTile.gridX
  local tempY = swapTile.gridY

  local newTile = board.tiles[y][x]

  swapTile.gridX = newTile.gridX
  swapTile.gridY = newTile.gridY
  newTile.gridX = tempX
  newTile.gridY = tempY

  -- swap tiles in the tiles table
  board.tiles[swapTile.gridY][swapTile.gridX] =
      swapTile

  board.tiles[newTile.gridY][newTile.gridX] = newTile
  
  return newTile
end


function PlayState:validateBoard()
  -- use function to check that the board in play has valid moves that can be made to result in a match of 3 or more
  
  -- update the boardCopy to reflect the current state of the active game board
  for y = 1, 8 do
    for x = 1, 8 do
      self.boardCopy.tiles[y][x].gridX = self.board.tiles[y][x].gridX
      self.boardCopy.tiles[y][x].gridY = self.board.tiles[y][x].gridY
      self.boardCopy.tiles[y][x].color = self.board.tiles[y][x].color
      self.boardCopy.tiles[y][x].variety = self.board.tiles[y][x].variety
      self.boardCopy.tiles[y][x].isShiney = self.board.tiles[y][x].isShiney
    end
  end
  
  local matches = nil
  local tileToSwap = nil
  local swappedTile = nil

  for y = 1, 8 do
    for x = 1, 8 do
      -- set variable holding tile to be swapped
      tileToSwap = self.boardCopy.tiles[y][x]
      -- check if swap can be made with tile to the left
      if x < 8 then
        swappedTile = self:performSwap(self.boardCopy, tileToSwap, y, x+1)
        matches = self.boardCopy:calculateMatches()
        if matches then
          --self:performSwap(self.boardCopy, tileToSwap, y, x+1)
          return true
        end
        self:performSwap(self.boardCopy, tileToSwap, y, x)
      end
      
      -- check if swap can be made with tile to the right
      if x > 1 then
        swappedTile = self:performSwap(self.boardCopy, tileToSwap, y, x-1)
        matches = self.boardCopy:calculateMatches()
        if matches then
          --self:performSwap(self.boardCopy, tileToSwap, y, x-1)
          return true
        end
        self:performSwap(self.boardCopy, tileToSwap, y, x)
      end
      
      -- check if swap can be made with tile from below
      if y < 8 then
        swappedTile = self:performSwap(self.boardCopy, tileToSwap, y+1, x)
        matches = self.boardCopy:calculateMatches()
        if matches then
          --self:performSwap(self.boardCopy, tileToSwap, y+1, x)
          return true
        end        
        self:performSwap(self.boardCopy, tileToSwap, y, x)
      end
      
      -- check if swap can be made with tile from above
      if y > 1 then
        swappedTile = self:performSwap(self.boardCopy, tileToSwap, y-1, x)
        matches = self.boardCopy:calculateMatches()
        if matches then
          --self:performSwap(self.boardCopy, tileToSwap, y-1, x)
          return true
        end        
        self:performSwap(self.boardCopy, tileToSwap, y, x)
      end
    end
  end
  --if not matches then
    return false
  --end
end


function PlayState:render()
    -- render board of tiles
    self.board:render()

    -- render highlighted tile if it exists
    if self.highlightedTile then
        
        -- multiply so drawing white rect makes it brighter
        love.graphics.setBlendMode('add')

        love.graphics.setColor(1, 1, 1, 0.38)
        love.graphics.rectangle('fill', (self.highlightedTile.gridX - 1) * 32 + (VIRTUAL_WIDTH - 272),
            (self.highlightedTile.gridY - 1) * 32 + 16, 32, 32, 4)

        -- back to alpha
        love.graphics.setBlendMode('alpha')
    end

    -- render highlight rect color based on timer
    if self.rectHighlighted then
        love.graphics.setColor(0.85, 0.34, 0.39, 1)
    else
        love.graphics.setColor(0.67, 0.2, 0.2, 1)
    end

    -- draw actual cursor rect
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', self.boardHighlightX * 32 + (VIRTUAL_WIDTH - 272),
        self.boardHighlightY * 32 + 16, 32, 32, 4)

    -- GUI text
    love.graphics.setColor(0.22, 0.22, 0.22, 0.92)
    love.graphics.rectangle('fill', 16, 16, 186, 116, 4)

    love.graphics.setColor(0.39, 0.61, 1, 1)
    love.graphics.setFont(gFonts['medium'])
    love.graphics.printf('Level: ' .. tostring(self.level), 20, 24, 182, 'center')
    love.graphics.printf('Score: ' .. tostring(self.score), 20, 52, 182, 'center')
    love.graphics.printf('Goal : ' .. tostring(self.scoreGoal), 20, 80, 182, 'center')
    love.graphics.printf('Timer: ' .. tostring(self.timer), 20, 108, 182, 'center')
end