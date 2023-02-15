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

grid={}
function grid:new()
 local o=setmetatable({},self)
 self.__index=self

 self.cells={}
 for i=1,gridcols*gridrows do
  add(self.cells,{})
 end

 return o
end

function grid:add(obj)
 obj.cellidx=cellidx(
  obj.x,obj.y
 )
 add(self.cells[cellidx],obj)
end

function grid:del(obj)
 local cells=self.cells
 local objd=del(
  cells[obj.cellidx],obj
 )
 assert(objd==obj)
 obj.cellidx=nil
end

function grid:_cellhit(
 ci,x,y,r,objx
)
 print(ci)
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
function grid:empty(x,y,r,objx)
 local ci=cellidx(x,y)

 
 for d in all(cell_deltas) do
  if self:_cellhit(
   ci+d,x,y,r,objx
  ) then
   return false
  end
 end
 
 return true
end

function _init()
 g=grid:new()
end

function _update()
 local obj={
  x=rnd(128),
  y=rnd(128),
  r=4
 }

 if g:empty(
  obj.x,obj.y,obj.r
 ) then
  g:add(obj) 
 end
end

function _draw()
 local c=0
 for cell in all(g.cells) do
  for obj in all(cell) do
   circ(obj.x,obj.y,obj.r,c+1)
  end
  c=(c+1)%15
 end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
