pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
frate=30
seed_r=2.5
tree_r=3
branch_l=6

function vlen(dx,dy)
 return sqrt(dx*dx+dy*dy)
end

--class inheritance
function extend(clz,baseclz)
 for k,v in pairs(baseclz) do
  clz[k]=v
 end
end

cellsz=16

cellgrid={}
function cellgrid:new(w,h)
 local o=setmetatable({},self)
 self.__index=self

 o.w=w or 128
 o.h=h or 128
 --extra empty col to facilitate
 --left and right neighbour
 --checks at edge of grid
 o.ncols=ceil(o.w/cellsz)+1
 o.nrows=ceil(o.h/cellsz)
 o.cells={}
 for i=1,o.ncols*o.nrows do
  add(o.cells,{})
 end

 return o
end

function cellgrid:_cellidx(x,y)
 --starts at one
 return 1+(
  (x\cellsz)+
  (y\cellsz)*self.ncols
 )
end

function cellgrid:_add(obj,ci)
 assert(obj.cellidx==nil)
 assert(
  ci%self.ncols!=0,
  "cannot add to wrapping col"
 )
 add(self.cells[ci],obj)
 obj.cellidx=ci
end

function cellgrid:add(obj)
 self:_add(
  obj,self:_cellidx(obj.x,obj.y)
 )
end

function cellgrid:del(obj)
 local cells=self.cells
 local objd=del(
  cells[obj.cellidx],obj
 )
 assert(objd==obj)
 obj.cellidx=nil
end

function cellgrid:moved(obj)
 local ci=self:_cellidx(
  obj.x,obj.y
 )
 if ci!=obj.cellidx then
  self:del(obj)
  self:_add(obj,ci)
 end
end

function cellgrid:_cellhit(
 ci,x,y,r,objx
)
 if ci<1 or ci>#self.cells then
  return false
 end

 for obj in all(self.cells[ci]) do
  if obj!=objx then
   local d=vlen(x-obj.x,y-obj.y)
   if d<obj.r+r then
    return true
   end
  end
 end
 return false
end

function cellgrid:fits(x,y,r,objx)
 if (
  x<r or x>self.w-r or
  y<r or y>self.h-r
 ) then
  return false
 end

 local ci=self:_cellidx(x,y)

 for dx=-1,1 do
  for dy=-1,1 do
   if self:_cellhit(
    ci+dx+dy*self.ncols,
    x,y,r,objx
   ) then
    return false
   end
  end
 end
 
 return true
end

function create_angles(n,dmin)
 local angles={}
 -- first angle is always zero

 while #angles<n-1 do
  --find range of options
  local r=0
  local ap=0
  for a in all(angles) do
   r+=max(0,a-ap-dmin*2)
   ap=a
  end
  r+=max(0,1-ap-dmin*2)

  if r==0 then
   -- no room remaining
   return
  end

  local v=rnd(r)

  local insertpos
  local ap=0
  for i,a in pairs(angles) do
   local w=max(0,a-ap-dmin*2)
   if v<w then
    insertpos=i
		  break
   end
   v-=w
   ap=a
  end
  local angle=ap+v+dmin
  if insertpos!=nil then
   add(angles,angle,insertpos)
  else
   add(angles,angle)
  end
 end

 add(angles,0)
 local offset=rnd(1)
 for i=1,#angles do
  angles[i]+=offset
  angles[i]-=flr(angles[i])
 end

 return angles
end

seed={}
function seed:new(dx,dy,o)
 local o=setmetatable(o or {},self)
 self.__index=self

 o.dx=dx
 o.dy=dy
 o.age=0
 o.growrate=(
  0.02+rnd(0.03)
 )/frate
 o.speed=o.speed or 0.1
 o.moving=true

 return o
end

function seed:update()
 self.age+=self.growrate
 if self.age>1 then
  --root and change into tree
  local t=tree:new(self.x,self.y)
  grid:add(t)
  add(trees,t)
  return true
 end

 if (not self.moving) return

 local dx=self.dx*self.speed
 local dy=self.dy*self.speed
 if grid:fits(
  self.x+dx,self.y+dy,self.r,self
 ) then
  self.x+=dx
  self.y+=dy
  grid:moved(self)
 else
  self.moving=false
  self.growrate*=2
 end
end

function seed:draw()
 circfill(
  self.x,self.y,self.r,10
 )
end

tree={}
function tree:new(x,y,o)
 local o=setmetatable(o or {},self)
 self.__index=self

 o.x=x
 o.y=y
 o.r=o.r or 3
 o.growrate=(
  0.04+rnd(0.02)
 )/frate
 o.maxseeds=o.maxseeds or 3
 o.color=o.color or 4

 o.age=0

 local angles=create_angles(
  o.maxseeds or 3,0.15
 )
 o.seeds={}
 for angle in all(angles) do
  add(o.seeds,seed:new(
   sin(angle),cos(angle)
  ))
 end

 return o
end

function tree:update()
 self.age+=self.growrate
 if (self.age<1) return

 --drop seeds before destroy
 for s in all(self.seeds) do
  s.x=self.x+s.dx*branch_l
  s.y=self.y+s.dy*branch_l
  s.r=seed_r
  if grid:fits(
   s.x,s.y,s.r
  ) then
   add(seeds,s)
   grid:add(s)
  end
 end

 return true
end

function tree:draw()
 --draw trunk
 local r=self.r*(
  min(1,self.age*2)
  -max(0,self.age-0.8)*5
 )
 circfill(
  self.x,self.y,r,self.color
 )

 --draw leaves
 local m=min(0.5,self.age-0.2)*2
 local r1=m*2.5
 local r2=m*branch_l
 for s in all(self.seeds) do
  local x=self.x+s.dx*r2
  local y=self.y+s.dy*r2
  circfill(x,y,r1,11)
 end
end

function _init()
 grid=cellgrid:new()
 trees={}
 seeds={}
 for i=1,10 do
  local t=nil
  while t==nil do
   local x=rnd(128)
   local y=rnd(128)
   if grid:fits(x,y,6) then
    t=tree:new(x,y)
   end
  end
  add(trees,t)
  grid:add(t)
 end
end

function _update()
 for i=#trees,1,-1 do
  local destroy=trees[i]:update()
  if destroy then
   grid:del(trees[i])
   trees[i]=trees[#trees]
   deli(trees,#trees)
  end
 end

 for i=#seeds,1,-1 do
  local destroy=seeds[i]:update()
  if destroy then
   grid:del(seeds[i])
   seeds[i]=seeds[#seeds]
   deli(seeds,#seeds)
  end
 end
end

function _draw()
 cls()
 foreach(seeds,seed.draw)
 foreach(trees,tree.draw)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
