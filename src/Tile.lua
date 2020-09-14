--[[
    GD50
    Match-3 Remake

    -- Tile Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    The individual tiles that make up our game board. Each Tile can have a
    color and a variety, with the varietes adding extra points to the matches.
]]

Tile = Class{}

function Tile:init(x, y, color, variety)
    
    -- board positions
    self.gridX = x
    self.gridY = y

    -- coordinate positions
    self.x = (self.gridX - 1) * 32
    self.y = (self.gridY - 1) * 32

    -- tile appearance/points
    self.color = color
    self.variety = variety
    self.isShiney = math.random(16) == 1 and true or false
    
    -- particle system belonging to the brick, emitted on hit
    self.psystem = love.graphics.newParticleSystem(gTextures['particle'], 24)

    -- various behavior-determining functions for the particle system
    -- https://love2d.org/wiki/ParticleSystem

    -- lasts between 0.5-1 seconds seconds
    self.psystem:setParticleLifetime(0.5, 1)

    -- give it an acceleration of anywhere between X1,Y1 and X2,Y2 (0, 0) and (80, 80) here
    -- gives generally downward 
    self.psystem:setLinearAcceleration(-5, 0, 15, 40)

    -- spread of particles; normal looks more natural than uniform
    self.psystem:setEmissionArea('normal', 5, 5)
    
    -- choose colour for particle system
    self.psystem:setColors(1,1,1,0.75, 1,1,1,0)
end

function Tile:update(dt)
  self.psystem:update(dt)
end

function Tile:render(x, y)
    
    -- draw shadow
    love.graphics.setColor(0.13, 0.13, 0.20, 1)
    love.graphics.draw(gTextures['main'], gFrames['tiles'][self.color][self.variety],
        self.x + x + 2, self.y + y + 2)

    -- draw tile itself
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(gTextures['main'], gFrames['tiles'][self.color][self.variety],
        self.x + x, self.y + y)
    
    if self.isShiney then
      -- if shiney make it glow
      love.graphics.setColor(1, 1, 1, 0.25)
      love.graphics.rectangle('fill', self.x + x + 2, self.y + y + 2, 28, 28, 6, 6)
      self:renderParticles(x, y)
    end
end

function Tile:renderParticles(x, y)
  self.psystem:emit(24)
  love.graphics.draw(self.psystem, self.x + x + 16, self.y + y + 16)
end