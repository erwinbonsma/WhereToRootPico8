pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
function vlen(dx,dy)
 return sqrt(dx*dx+dy*dy)
end

--class inheritance
function extend(clz,baseclz)
 for k,v in pairs(baseclz) do
  clz[k]=v
 end
end

cellw=16
cellh=16
gridw=128
gridh=128
gridcols=gridw\cellw+2
gridrows=gridh\cellh+2

function cellidx(x,y)
 return gridcols+1+(
  (x\cellw)
  +(y\cellh)*gridcols
 )
end

cellgrid={}
function cellgrid:new()
 local o=setmetatable({},self)
 self.__index=self

 self.cells={}
 for i=1,gridcols*gridrows do
  add(self.cells,{})
 end

 return o
end

function cellgrid:add(obj)
 obj.cellidx=cellidx(
  obj.x,obj.y
 )
 add(
  self.cells[obj.cellidx],obj
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

function cellgrid:_cellhit(
 ci,x,y,r,objx
)
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

cell_deltas={
 0,-1,1,-gridcols,gridcols
}
function cellgrid:empty(x,y,r,objx)
 local ci=cellidx(x,y)
 
 for dx=-1,1 do
  for dy=-1,1 do
   if self:_cellhit(
    ci+dx+dy*gridcols,x,y,r,objx
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

tree={}
function tree:new(x,y,o)
 local o=setmetatable(o or {},self)
 self.__index=self

 o.x=x
 o.y=y
 o.r=o.r or 3
 o.growrate=0.1
 o.maxseeds=o.maxseeds or 3
 o.color=o.color or 4

 o.age=0

 o.seed_angles=create_angles(
  o.maxseeds or 3,0.15
 )

 return o
end

function tree:draw()
 circfill(
  self.x,self.y,self.r,self.color
 )
 for a in all(self.seed_angles) do
  local x=self.x+cos(a)*self.r*2
  local y=self.y+sin(a)*self.r*2
  circfill(x,y,2,11)
 end
end

tree_r=3
function _init()
 grid=cellgrid:new()
 trees={}
 for i=1,10 do
  local t=nil
  while t==nil do
   local x=rnd(128)
   local y=rnd(128)
   if grid:empty(x,y,6) then
    t=tree:new(x,y)
   end
  end
  add(trees,t)
  grid:add(t)
 end
end

function _update()
end

function _draw()
 cls()
 for t in all(trees) do
  t:draw()
 end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
