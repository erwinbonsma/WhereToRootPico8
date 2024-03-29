pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- root to remain v1.0
-- (c) 2023  eriban

--cartdata
vmajor=0
vminor=2

frate=60
seed_r=2.2
tree_r=3
root_r=5
max_r=root_r
tree_h=5
branch_l=8
yscale=0.75
seeddrop_h=6

cellsz=8
roots_r=16
default_maxgrowrate=0.1/frate
slowgrowrate=0.05/frate
maxgrowrate=default_maxgrowrate

seedspeed=6
seedgrowrate=0.06/frate

treechar="\^:1c221c0808000000"

player_pals={
 {--red
  [6]=8,[5]=2,[7]=14
 },
 {--pink
  [6]=14,[5]=2,[7]=15
 },
 {--green
  [6]=10,[5]=3,[7]=11
 },
 {--blue
  [6]=13,[5]=2,[7]=12
 }
}

--maps level-menu positions to
--levels
levelmenu_pos={
 1, 2, 3,11,
 7, 6, 4, 5,
 8,10, 9,12,
 0,13,14,15,
}

level_defs={{
 name="intro",
 mapdef={0,0,15,15},
 goals={{3,3,3,3},{9,9,3,3},{9,3,3,3},{3,9,3,3}},
 plyrs={{36,36}}
},{
 name="walls",
 mapdef={15,0,15,15},
 goals={{3,3,4,4},{8,8,4,4},{8,3,4,4},{3,8,4,4}},
 plyrs={{40,40}}
},{
 name="tiles",
 mapdef={30,0,15,15},
 goals={{3,3,3,3},{9,9,3,3},{9,3,3,3},{3,9,3,3}},
 plyrs={{36,36}}
},{
 name="water",
 mapdef={45,0,15,15},
 goals={{2,2,4,4},{9,9,4,4},{9,2,4,4},{2,9,4,4}},
 plyrs={{32,32}}
},{
 name="bridges",
 mapdef={90,0,15,15},
 goals={{2,2,3,3},{10,10,3,3},{10,2,3,3},{2,10,3,3}},
 plyrs={{28,28}}
},{
 name="duel",
 mapdef={74,0,17,17},
 goals={{2,3,3,3},{12,11,3,3},{12,3,3,3},{2,11,3,3}},
 plyrs={{68,22},{68,116}}
},{
 name="square",
 mapdef={0,0,15,15},
 goals={{3,3,3,3},{9,9,3,3},{9,3,3,3},{3,9,3,3}},
 plyrs={{36,36},{84,36},{36,84},{84,84}},
 maxgrowrate=slowgrowrate
},{
 name="islands",
 mapdef={0,15,15,15},
 goals={{1,1,5,5},{9,9,5,5},{9,1,5,5},{1,9,5,5}},
 plyrs={{28,28},{92,92},{92,28},{28,92}},
 maxgrowrate=slowgrowrate
},{
 name="check 1",
 mapdef={14,15,16,16},
 target=8,
 plyrs={{64,64}},
 maxgrowrate=slowgrowrate
},{
 name="check 2",
 mapdef={75,17,16,16},
 target=8,
 plyrs={{64,64}},
 maxgrowrate=slowgrowrate
},{
 name="spiral",
 mapdef={59,0,16,16},
 goals={{6,6,4,4}},
 plyrs={{24,24}}
},{
 name="holes",
 mapdef={29,15,16,16},
 plyrs={{20,20}},
 goals={{12,12,3,3}}
},{
 name="quest",
 mapdef={60,16,15,15},
 plyrs={{20,20},{100,20},{20,100},{60,60}},
 goals={{11,11,3,3}},
 weeds=true
},{
 name="battle",
 mapdef={45,15,15,15},
 plyrs={{20,20},{100,20},{20,100},{60,60}},
 weeds=true
},{
 name="siege",
 mapdef={90,15,16,16},
 plyrs={{24,64},{64,32},{64,96},{104,64}},
 weeds=true
}}

--sprite flags
flag_goal=0
flag_wall=1
flag_water=2
flag_barren=3

--goal types
goal_areas=0
goal_finish=1
goal_count=2
goal_kill=3

function vlen(dx,dy)
 if abs(dx)+abs(dy)>100 then
  --guard against overflows
  return 100
 else
  return sqrt(dx*dx+dy*dy)
 end
end

function fill(s,fill)
 if #s>=#fill then
  return s
 end
 return sub(fill,#fill-#s+1)..s
end

function time_str(t)
 return (
  tostr(flr(t/60))..":"..
  fill(tostr(flr(t%60)),"00")
 )
end

function pred_true()
 return true
end

function printbig(s,x0,y0,c)
 print(s,x0,y0,c)
 for y=4,0,-1 do
  local yd=y0+y*2
  for x=#s*4,0,-1 do
   local xd=x0+x*2
   rectfill(
    xd,yd,xd+1,yd+1,
    pget(x0+x,y0+y)
   )
  end
 end
end

--wrap coroutine with a name to
--facilitate debugging crashes
function cowrap(
 name,coroutine,...
)
 local w={
  name=name,
  coroutine=cocreate(coroutine),
  args={...}
 }
 return w
end

--returns true when routine died
function coinvoke(wrapped_cr)
 local cr=wrapped_cr.coroutine
 if not coresume(
  cr,
  wrapped_cr.args
 ) then
  printh(
   "coroutine "..
   wrapped_cr.name.." crashed"
  )
  while true do end
 end
 return costatus(cr)=="dead"
end

function wait(steps)
 for i=1,steps do
  yield()
 end
end

function istree(obj)
 return getmetatable(obj)==tree
end

function isseed(obj)
 return getmetatable(obj)==seed
end

--class inheritance
function extend(clz,baseclz)
 for k,v in pairs(baseclz) do
  clz[k]=v
 end
end

function actionkeyp()
 return btnp(❎) or btnp(🅾️)
end

function drawlogo()
 palt(0xfffe)
 pal(15,5)
 spr(32,20,2,11,1)
 spr(32,19,3,11,1)
 pal(15,0)
 spr(32,21,3,11,1)
 spr(32,20,4,11,1)
 pal(15,4)
 spr(32,20,3,11,1)
 pal(0)
 palt()
end

function print_time(
 time_taken,x,y
)
 local str=time_str(time_taken)
 print(
  "⧗"..str,x-#str*4-6,y
 )
end

function print_trees(trees,x,y)
 local str=""..trees
 print(
  str..treechar,x-#str*4-6,y
 )
end


stats={}

function stats:new()
 local o=setmetatable({},self)
 self.__index=self

 cartdata("eriban_where2root")
 if (
  dget(0)!=vmajor or
  dget(1)<vminor
 ) then
  --reset incompatible data
  for l=1,#level_defs do
   dset(l*2,0)
  end
 end

 dset(0,vmajor)
 dset(1,vminor)

 return o
end

function stats:mark_done(
 level,time_taken,total_trees
)
 local cur=self:get_stats(level)
 if cur==nil then
  cur={
   total_trees=999,
   time_taken=3599
  }
 end
 dset(level*2,min(total_trees,
  cur.total_trees))
 dset(level*2+1,min(time_taken,
  cur.time_taken))
end

function stats:is_done(level)
 return dget(level*2)>0
end

function stats:get_stats(level)
 local trees=dget(level*2)
 if trees>0 then
  return {
   total_trees=trees,
   time_taken=dget(level*2+1)
  }
 end
end

function stats:update()
 if actionkeyp() then
  scene=levelmenu
 end
end

function stats:draw()
 cls(0)
 rectfill(12,0,115,128,1)

 drawlogo()

 print(
  "level      time  trees",
  24,15,9
 )

 color(4)

 for n,ld in pairs(level_defs) do
  local y=n*7+15
  print(ld.name,24,y)
  if self:is_done(n) then
   local s=self:get_stats(n)
   print_time(
    s.time_taken,82,y
   )
   print_trees(
    s.total_trees,112,y
   )
  end
  spr(
   43+level_goal_type(n),16,y
  )
 end
end

levelmenu={}

function levelmenu:new()
 local o=setmetatable({},self)
 self.__index=self

 o.grid=cellgrid:new({
  mx=111,my=0,nrows=17,ncols=17
 })

 o.hbridges={}
 for b in all({0,1,4,5,6,9,12,13,14}) do
  o.hbridges[b]=true
 end
 o.vbridges={}
 for b in all({2,3,4,6,7,8,9}) do
  o.vbridges[b]=true
 end

 for p=15,0,-1 do
  o:_setpos(p)
  if (
   o.lvl!=0
   and stats:is_done(o.lvl)
  ) then
   o:_addtree(1)
  end
 end

 return o
end

function levelmenu:_setpos(pos)
 if self.pos!=nil then
  for x=1,3 do
   for y=1,3 do
    local odd=(x+y)%2==0
    mset(
     self.grid.mx+x+self.cx*4,
     self.grid.my+y+self.cy*4,
     odd and 48 or 49
    )
   end
  end
 end

 self.pos=pos
 self.cx=pos%4
 self.cy=flr(pos/4)
 self.lvl=levelmenu_pos[pos+1]
 if self.lvl>0 then
  self.tree=stats:is_done(
   self.lvl
  )
  self.goal=level_goal(self.lvl)
 else
  self.tree=false
  self.goal=nil
 end

 for x=1,3 do
  for y=1,3 do
   mset(
    self.grid.mx+x+self.cx*4,
    self.grid.my+y+self.cy*4,
    50
   )
  end
 end
end

--add tree at current position
function levelmenu:_addtree(age)
 self.grid:add(tree:new(
  self.cx*32+20,
  self.cy*32+20,{
   age=age,
   preserve=true,
   seeds={},
   player={pal=player_pals[1]}
  }
 ))
 self.tree=true
end

function levelmenu:_can_move(
 p1,p2
)
 assert(p2>p1)
 if not (
  p2-p1==1
  and self.hbridges[p1]
 ) and not (
  p2-p1==4
  and self.vbridges[p1]
 ) then
  --there's no bridge
  return false
 end

 for p in all({p1,p2}) do
  if stats:is_done(
   levelmenu_pos[p+1]
  ) then
   return true
  end
 end

 return false
end

function levelmenu:_try_move(
 delta_pos
)
 local pnew=self.pos+delta_pos
 if self:_can_move(
  min(self.pos,pnew),
  max(self.pos,pnew)
 ) then
  self:_setpos(pnew)
  sfx(12)
 else
  sfx(13)
 end
end

function levelmenu:update()
 if btnp(⬅️) and self.cx>0 then
  self:_try_move(-1)
 end
 if btnp(➡️) and self.cx<3 then
  self:_try_move(1)
 end
 if btnp(⬆️) and self.cy>0 then
  self:_try_move(-4)
 end
 if btnp(⬇️) and self.cy<4 then
  self:_try_move(4)
 end
 if actionkeyp() then
  if self.lvl>0 then
   scene=game:new(self.lvl)
  else
   scene=stats
  end
 end

 if (
  not self.tree and
  stats:is_done(self.lvl)
 ) then
  self:_addtree(0)
 end

 self.grid:update_units()
end

function levelmenu:draw()
 cls(6)

 camera(4,-14)
 self.grid:draw()

 palt(7,true)
 palt(0,false)

 for p=0,19 do
  local x=(p%4)*32+16
  local y=flr(p/4)*24+10

  if self.hbridges[p] then
   local f=self:_can_move(
    p,p+1
   )
   spr(f and 61 or 62,x+16,y)
   spr(f and 53 or 54,x+16,y+6)
  end

  if self.vbridges[p] then
   local f=self:_can_move(
    p,p+4
   )
   spr(f and 61 or 63,x,y+12)
  end
 end

 palt()
 self.grid:visit_units(
  draw_treetop
 )

 camera()

 drawlogo()

 if self.lvl==0 then
  print("stats",4,120,4)
  return
 end

 spr(
  self.goal.sprite_idx,5,119
 )
 local name=level_defs[
  self.lvl
 ].name
 print(name,15,120,4)

 local s=stats:get_stats(
  self.lvl
 )
 if s!=nil then
  print_time(
   s.time_taken,97,120
  )
  print_trees(
   s.total_trees,123,120
  )
 end
end
-->8
--cellgrid

cellgrid={}
function cellgrid:new(o)
 o=setmetatable(o or {},self)
 self.__index=self

 o.nrows=o.nrows or 18
 o.ncols=o.ncols or 16

 o.head={
  x=0,y=-100,r=0
 }
 o.tail={
  x=0,y=o.nrows*8+100,r=0
 }
 o.head._nxt=o.tail
 o.tail._prv=o.head

 o.observers={}

 return o
end

--insert obj into linked list,
--after prev
function cellgrid:_insert(
 prev,obj
)
 assert(
  obj._nxt==nil and
  obj._prv==nil
 )
 assert(
  prev.y<=obj.y and
  obj.y<=prev._nxt.y
 )

 obj._nxt=prev._nxt
 obj._prv=prev
 obj._nxt._prv=obj
 prev._nxt=obj
end

function cellgrid:_obj_before_y(
 y,start_at
)
 local prev=start_at
 if prev==nil then
  if y<self.nrows*4 then
   prev=self.head
  else
   prev=self.tail._prv
  end
 end

 while prev._nxt.y<y do
  prev=prev._nxt
 end
 while prev.y>y do
  prev=prev._prv
 end

 assert(
  prev.y<=y and prev._nxt.y>=y
 )
 return prev
end

function cellgrid:_remove(obj)
 assert(
  obj._nxt!=nil and
  obj._prv!=nil
 )
 assert(
  obj._prv._nxt==obj and
  obj._nxt._prv==obj
 )
 obj._prv._nxt=obj._nxt
 obj._nxt._prv=obj._prv
 obj._prv=nil
 obj._nxt=nil
end

function cellgrid:add_observer(
 observer
)
 add(self.observers,observer)
end

function cellgrid:add(obj)
 self:_insert(
  self:_obj_before_y(obj.y),obj
 )
 assert(obj.grid==nil)
 obj.grid=self

 for o in all(self.observers) do
  o:unit_added(obj)
 end
end

function cellgrid:del(obj)
 self:_remove(obj)
 assert(obj.grid==self)

 for o in all(self.observers) do
  o:unit_removed(obj)
 end

 obj.grid=nil
end

function cellgrid:moved(obj)
 if (
  obj._prv.y<=obj.y and
  obj._nxt.y>=obj.y
 ) then
  --position in linked-list
  --remains unchanged
  return
 end

 local start_at=obj._prv
 self:_remove(obj)
 local prev=self:_obj_before_y(
  obj.y,start_at
 )
 self:_insert(prev,obj)
end

function cellgrid:_invalid_pos(
 x,y
)
 return (
  x<0 or x>=self.ncols*8 or
  y<0 or y>=self.nrows*8
 )
end

function cellgrid:_maphit(
 x,y,vx,vy,r
)
 if (vx==0 and vy==0) return true

 local cz=cellsz
 local mx,my=x%cz,y%cz
 --dx/dy is distance along axis
 --to cell in dir specified by
 --vx/vy
 local dx=vx*((cz+vx*cz)/2-mx)
 local dy=vy*((cz+vy*cz)/2-my)

 return (dx*dx+dy*dy < r*r)
end

function cellgrid:_cellhasflag(
 mx,my,flag
)
 local si=mget(
  self.mx+mx,self.my+my
 )
 return fget(si,flag)
end

function cellgrid:_poshasflag(
 x,y,flag
)
 return self:_cellhasflag(
  flr(x/cellsz),
  flr(y/cellsz),
  flag
 )
end

function cellgrid:isgoal(x,y)
 return self:_poshasflag(
  x,y,flag_goal
 )
end

function cellgrid:iswater(x,y)
 return self:_poshasflag(
  x,y,flag_water
 )
end

function cellgrid:isbarren(x,y)
 return self:_poshasflag(
  x,y,flag_barren
 )
end

--the direction a seed above
--the water is pushed in (by the
--neighbouring ground) to be
--fully above the water
function cellgrid:water_force(
 x,y,r
)
 local mx=flr(x/cellsz)
 local my=flr(y/cellsz)

 local fx=0
 local fy=0
 for v in all({-1,1}) do
  if (
   self:_maphit(x,y,v,0,r) and
   not self:_cellhasflag(
    mx+v,my,flag_water
   )
  ) then
   fx=-v
  end
  if (
   self:_maphit(x,y,0,v,r) and
   not self:_cellhasflag(
    mx,my+v,flag_water
   )
  ) then
   fy=-v
  end
 end

 return {x=fx,y=fy}
end

function cellgrid:hits_wall(
 x,y,r
)
 local mx=flr(x/cellsz)
 local my=flr(y/cellsz)
 for dx=-1,1 do
  for dy=-1,1 do
   if self:_maphit(
    x,y,dx,dy,r
   ) and self:_cellhasflag(
    mx+dx,my+dy,flag_wall
   ) then
    return true
   end
  end
 end

 return false
end

function cellgrid:_fits_map(
 x,y,r
)
 if (self.mx==nil) return true

 local mx=flr(x/cellsz)
 local my=flr(y/cellsz)

 for dx=-1,1 do
  for dy=-1,1 do
   if (
    dx!=0 or dy!=0
   ) and self:_maphit(
    x,y,dx,dy,r
   ) and self:_cellhasflag(
    mx+dx,my+dy,flag_wall
   ) then
    return false
   end
  end
 end

 return true
end

--visits all objects that an
--object at position (x,y) with
--radius r hits.
-- when objx is provided, it is
--the starting point for the
--search but excluded
-- search is aborted when the
--visitor return true
function cellgrid:visit_hits(
 x,y,r,visitor,objx
)
 if self:_invalid_pos(x,y) then
  return
 end

 local obj=self:_obj_before_y(
  y-r-max_r,objx
 )
 local maxy=y+r+max_r
 while obj.y<=maxy do
  if obj!=objx then
   if (
    vlen(x-obj.x,y-obj.y)
    <obj.r+r
   ) then
    if (visitor(obj)) return
   end
  end
  obj=obj._nxt
 end
end

function cellgrid:fits(
 x,y,r,objx
)
 if (
  self:_invalid_pos(x,y)
  or not self:_fits_map(x,y,r)
 ) then
  return false
 end

 local fits=true
 local visitor=function(obj)
  fits=false
  return true --abort search
 end

 self:visit_hits(
  x,y,r,visitor,objx
 )

 return fits
end

function cellgrid:update_units()
 local unit=self.head._nxt

 while unit!=self.tail do
  local destroy=unit:update()
  local nxt=unit._nxt

  if (destroy) self:del(unit)

  unit=nxt
 end
end

function cellgrid:visit_units(
 visitor
)
 local unit=self.head._nxt

 while unit!=self.tail do
  visitor(unit)
  unit=unit._nxt
 end
end

--draws all units with y<maxy
--ordered by their y position.
--starts from start_unit (or
--first unit if nil).
--return first unit with y>=maxy
function cellgrid:draw_units(
 start_unit,maxy
)
 local unit=(
  start_unit or self.head._nxt
 )
 maxy=maxy or self.nrows*8

 while unit.y<maxy do
  unit:draw()
  unit=unit._nxt
 end

 return unit
end

function cellgrid:draw()
 assert(self.mx!=nil)
 local drawunit=nil
 for row=1,self.nrows do
  palt(7,true)
  palt(0,false)
  map(
   self.mx,self.my+row-1,
   0,row*6-8,self.ncols,1
  )
  pal(0)

  drawunit=self:draw_units(
   drawunit,row*cellsz
  )
 end
end

--creates a function that checks
--if a grid cell coordinate is
--inside a given rectangle
function rectgoal(args)
 local x0,y0=args[1],args[2]
 local w,h=args[3],args[4]

 return function(x,y)
  return (
   x>=x0 and x<x0+w and
   y>=y0 and y<y0+h
  )
 end
end

--goal where player needs to
--have at least one tree in each
--of the areas
areagoal={}
function areagoal:new(
 areas,players
)
 local o=setmetatable({},self)
 self.__index=self

 o.areas=areas
 o.players=players

 o.counts={}
 for plyr in all(players) do
  local pc={}
  for area in all(areas) do
   pc[area]=0
  end
  o.counts[plyr]=pc
 end
 o.winner=nil

 o.sprite_idx=(
  #areas>1 and 22 or 23
 )

 return o
end

function areagoal:_is_done(
 counts
)
 for area in all(self.areas) do
  if (counts[area]==0) return
 end
 return true
end

function areagoal:unit_added(
 unit
)
 local plyr=unit.player

 if (
  not istree(unit)
  or (
   --only human can win finish
   --goal
   #self.areas==1
   and plyr!=self.players[1]
  )
 ) then
  return
 end

 local cellx=unit.x/cellsz
 local celly=unit.y/cellsz
 for area in all(self.areas) do
  if area(cellx,celly) then
   local cf=self.counts[plyr]
   cf[area]+=1
   unit.area=area
   if (
    cf[area]==1 and
    self:_is_done(cf)
   ) then
    self.winner=plyr
   end
   return
  end
 end

 unit.area=nil
end

function areagoal:unit_removed(
 unit
)
 if unit.area!=nil then
  self.counts[
   unit.player][unit.area]-=1
  unit.area=nil
 end
end

function areagoal:draw()
 spr(self.sprite_idx,5,119)

 if (#self.areas==1) return

 local x=15
 for p in all(self.players) do
  pal(p.pal)
  for n,a in pairs(self.areas) do
   local sx=x+flr((n%4)/2)*4
   local sy=119+((n+1)%2)*4
   if self.counts[p][a]>0 then
    spr(26,sx,sy)
   else
    pset(sx+1,sy+1,6)
   end
  end
  x+=8
 end
 pal(0)
end

treegoal={}
function treegoal:new(
 grid,players,target
)
 local o=setmetatable({},self)
 self.__index=self

 o.grid=grid
 o.players=players
 o.target=target

 o.counts={}
 for plyr in all(players) do
  o.counts[plyr]=0
 end
 o.winner=nil

 o.sprite_idx=24

 return o
end

function treegoal:unit_added(
 unit
)
 if (not istree(unit)) return

 unit.goal=grid:isgoal(
  unit.x,unit.y
 )

 if unit.goal then
  local plyr=unit.player
  local c=self.counts
  c[plyr]+=1
  if c[plyr]>=self.target then
   self.winner=plyr
  end
 end
end

function treegoal:unit_removed(
 unit
)
 if unit.goal then
  self.counts[unit.player]-=1
  unit.goal=nil
 end
end

function treegoal:draw()
 spr(self.sprite_idx,5,119)

 local x=13
 local c=self.counts
 for p in all(self.players) do
  pal(p.pal)
  for n=0,self.target-1 do
   spr(
    c[p]>n and 27 or 28,x,119
   )
   x+=2
  end
  x+=4
 end
 pal(0)
end

killgoal={}
function killgoal:new(
 grid,players
)
 local o=setmetatable({},self)
 self.__index=self

 o.grid=grid
 o.players=players

 o.counts={}
 for plyr in all(players) do
  o.counts[plyr]=0
 end
 o.total=0
 o.winner=nil

 o.sprite_idx=25

 return o
end

function killgoal:unit_added(
 unit
)
 self.counts[unit.player]+=1
 self.total+=1
end

function killgoal:unit_removed(
 unit
)
 local plyr=unit.player
 local c=self.counts
 c[plyr]-=1
 self.total-=1
 if (c[plyr]>0) return

 for p in all(self.players) do
  if c[p]==self.total then
   self.winner=p
  end
 end
end

function killgoal:draw()
 spr(self.sprite_idx,5,119)

 local x=7
 local c=self.counts
 for p in all(self.players) do
  if x>7 then
   pal(p.pal)
   spr(
    c[p]>0 and 16 or 17,x,117
   )
  end
  x+=8
 end
 pal(0)
end

function level_goal_type(level)
 local ld=level_defs[level]
 if ld.goals then
  if #ld.goals>1 then
   return goal_areas
  else
   return goal_finish
  end
 elseif ld.weeds then
  return goal_kill
 else
  assert(ld.target>0)
  return goal_count
 end
end

function level_goal(
 level,players
)
 local ld=level_defs[level]
 players=players or {}

 if ld.goals then
  local areas={}
  for args in all(ld.goals) do
   add(areas,rectgoal(args))
  end

  return areagoal:new(
   areas,players
  )
 elseif ld.weeds then
  return killgoal:new(
   grid,players
  )
 else
  return treegoal:new(
   grid,players,ld.target
  )
 end
end
-->8
--animations

function drop(obj,ymax,bounce)
 local a=0.03
 local v=0

 while true do
  v+=a
  obj.y+=v
  if obj.y>ymax then
   obj.y=ymax
   if v>0.5 and bounce then
    v=-v*0.5
    sfx(16)
   else
    return
   end
  end

  yield()
 end
end

function title_anim(args)
 local s=args[1]

 s.treeh=0
 s.branchl=0
 s.seedr=0
 s.logo={y=-50}

 drop(s.logo,10,true)

 wait(5)
 sfx(15)

 local seed={y=-8,r=8}
 s.seed=seed
 drop(seed,120,true)

 while seed.r>1 do
  wait(10)
  seed.r-=1
  seed.y+=1
 end

 wait(60)
 s.seed=nil

 sfx(17)
 for i=1,124 do
  s.treeh+=0.5
  s.branchl+=0.25
  yield()
 end

 while s.seedr<8.5 do
  s.seedr+=0.08
  yield()
 end
 sfx(18)

 wait(120)
end

function seeddrop_anim(args)
 local s=args[1]
 local kills=args[2]
 local use_sfx=args[3]

 s.si=5
 s.vh=0
 while s.h>0 do
  s.vh-=0.02
  s.h+=s.vh
  yield()

  if s.h<4 and kills!=nil then
   for kill in all(kills) do
    if isseed(kill) then
     kill.anim=cowrap(
      "seedsquash",
      seedsquash_anim,kill
     )
    else
     kill.destroy=true
    end
   end
   kills=nil
  end
 end

 if (use_sfx) sfx(10)
end

function seedsquash_anim(args)
 local s=args[1]
 local use_sfx=args[2]

 if (use_sfx) sfx(6)

 s.si=13
 wait(8)

 while s.si<15 do
  s.si+=1
  wait(8)
 end

 s.destroy=true
end

function seedsplat_anim(args)
 local s=args[1]
 local use_sfx=args[2]

 s.vh=0
 while s.h>2 do
  s.vh-=0.02
  s.h+=s.vh
  yield()
 end

 s.h=2
 s.vh=nil

 seedsquash_anim({s,use_sfx})
end

function waterdrop_anim(args)
 local s=args[1]
 local use_sfx=args[2]

 local f=grid:water_force(
  s.x,s.y,s.r
 )

 while f.x!=0 or f.y!=0 do
  s.x+=f.x*seedspeed/frate
  s.y+=f.y*seedspeed/frate
  yield()
  f=grid:water_force(
   s.x,s.y,s.r
  )
  s.vh=0
 end

 s.h0=-3
 while s.h>-6 do
  s.vh-=0.02
  s.h+=s.vh
  yield()
 end
 s.h=-3
 s.vh=nil

 if (use_sfx) sfx(9)
 s.si_delta=0
 s.si=8
 wait(4)

 while s.si<12 do
  s.si+=1
  wait(4)
 end

 s.destroy=true
end

function seedroot_anim(args)
 local s,t=args[1],args[2]
 local use_sfx=args[3]

 if (use_sfx) sfx(11)

 s.vh=0.5
 while s.h>0 or s.vh>0 do
  s.vh-=0.02
  s.h+=s.vh
  yield()
 end

 if t==nil then
  --seed attempt on barren
  seedsquash_anim({s,use_sfx})
  return
 end

 yield()

 if (use_sfx) sfx(15)
 for i=0,s.si-1 do
  s.h=-i
  wait(20)
 end

 if t:fits() then
  grid:add(t)
 else
  if (use_sfx) sfx(14)
 end

 s.destroy=true
end

function seedrot_anim(args)
 local s=args[1]

 while s.si>1 do
  s.si-=1
  wait(30)
 end

 s.destroy=true
end

function gameend_anim()
 wait(180)

 scene=levelmenu
end

function gamestart_anim(args)
 local s=args[1]

 drop(s.dialog,54,true)

 wait(120)
 sfx(3)

 drop(s.dialog,128)
end
-->8
--seed

seed={}
function seed:new(dx,dy,o)
 o=setmetatable(o or {},self)
 self.__index=self

 o.dx=dx
 o.dy=dy
 o.age=0
 o.growrate=
  o.player.seedgrowrate
  or seedgrowrate
 o.speed=
  o.player.seedspeed
  or seedspeed
 o.moving=true
 o.anim=nil
 o.si=5
 o.si_delta=
  o.player.seed_si_delta or 0
 o.h0=0 --ground level

 return o
end

function seed:can_root(
 ignore_barren
)
 return (
  self.anim==nil or
  self.anim.name=="rot"
 ) and
 not grid:iswater(
  self.x,self.y
 ) and (
  ignore_barren or
  not grid:isbarren(
   self.x,self.y
  )
 )
end

function seed:approaching_water()
 return (
  self.moving and
  self.grid:iswater(
   self.x+self.dx*self.speed,
   self.y+self.dy*self.speed
  )
 )
end

function seed:is_rooting()
 return (
  self.anim!=nil and
  self.anim.name=="root"
 )
end

function seed:root(
 try_on_barren
)
 if not self:can_root(true) then
  return false
 end

 local barren=grid:isbarren(
  self.x,self.y
 )
 local t=nil
 if barren then
  if (not try_on_barren) return
 else
  t=tree:new(
   self.x,self.y,{
    player=self.player
   }
  )
 end

 self.anim=cowrap(
  "root",seedroot_anim,self,t,
  self.player.use_sfx
 )

 --anim destroys seed

 return true
end

function seed:update()
 if self.destroy then
  --handle destruction by other
  --seeds w/o impacting ongoing
  --seed update iteration
  return true
 end

 if self.anim!=nil then
  if coinvoke(self.anim) then
   self.anim=nil
  end

  return self.destroy
 end

 self.age+=self.growrate

 if self.age>1 then
  self.anim=cowrap(
   "rot",seedrot_anim,self
  )
 end

 if grid:iswater(
  self.x,self.y
 ) then
  self.anim=cowrap(
   "waterdrop",
   waterdrop_anim,self,
   self.player.use_sfx
  )
 end

 if (not self.moving) return

 local v=self.speed/frate
 local dx,dy=self.dx*v,self.dy*v
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

 if self.anim==nil then
  --reset drop speed if any
  self.h=0
  self.vh=0
 end
end

function seed:draw()
 local y=flr(
  self.y*yscale
 )-self.h-5
 pal(self.player.pal)
 if self.h>=self.h0 then
  spr(
   self.si+self.si_delta,
   self.x-4,y
  )
 else
  sspr(
   self.si*8,self.si_delta/2,
   8,6+self.h-self.h0,
   self.x-4,y
  )
 end

 pal(0)
end

-->8
--tree

function create_angles(n,dmin)
 local angles={}
 -- first angle is always zero

 while #angles<n-1 do
  --find range of options
  local r,ap=0,0
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
  local ap,insertpos=0
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
 o=setmetatable(o or {},self)
 self.__index=self

 o.x=x
 o.y=y
 o.r=tree_r
 o.maxseeds=
  o.player.treemaxseeds or 3

 o.age=o.age or 0
 o.rate_refresh=0

 o.seeds=o.seeds or nil

 return o
end

function tree:_blossom()
 local angles=create_angles(
  self.maxseeds,0.15
 )

 self.seeds={}
 for a in all(angles) do
  local s=seed:new(
   sin(a),cos(a),{
    player=self.player
   }
  )
  s.x=self.x+s.dx*branch_l
  s.y=self.y+s.dy*branch_l
  s.r=seed_r
  if hgrid:fits(s.x,s.y,s.r) then
   s.h=seeddrop_h
   s.si=1
   hgrid:add(s)
   add(self.seeds,s)
  end
 end
end

function tree:_can_drop(
 s,kills
)
 if grid:hits_wall(
  s.x,s.y,s.r
 ) then
  return false
 end

 local fits=true
 local visitor=function(obj)
  --drop destroys seeds and
  --small trees
  if isseed(obj) then
   add(kills,obj)
  else
   assert(istree(obj))
   if obj.age<0.25 then
    add(kills,obj)
   else
    --high tree prevents drop
    fits=false
   end
  end
 end

 grid:visit_hits(
  s.x,s.y,s.r,visitor
 )

 return fits
end

function tree:_dropseeds()
 local use_sfx=self.player.use_sfx

 for s in all(self.seeds) do
  hgrid:del(s)

  local kills={}
  local drop_sfx=use_sfx
  local splat_sfx=use_sfx
  if self:_can_drop(
   s,kills
  ) then
   s.anim=cowrap(
    "seeddrop",seeddrop_anim,
    s,kills,drop_sfx
   )
   drop_sfx=false
  else
   s.anim=cowrap(
    "seedsplat",seedsplat_anim,
    s,splat_sfx
   )
   splat_sfx=false
  end

  self.grid:add(s)
 end
end

function tree:_update_growrate()
 local c=1 --crowdedness
 local visitor=function(obj)
  if istree(obj) then
   local d=vlen(
    obj.x-self.x,obj.y-self.y
   )
   c+=max(roots_r-d,0)/roots_r
  end
 end
 self.grid:visit_hits(
  self.x,self.y,roots_r,
  visitor,self
 )

 self.growrate=maxgrowrate/c
end

--check if tree fits. there
--should not be another tree
--nearby
function tree:fits()
 local fits=true
 local visitor=function(obj)
  if istree(obj) then
   fits=false
  end
 end

 grid:visit_hits(
  self.x,self.y,root_r,
  visitor
 )

 return fits
end

function tree:h()
 return flr(
  min(self.age,0.25)*4*tree_h
 )
end

function tree:update()
 if (self.destroy) return true
 if (self.skip_update) return

 if self.age>=self.rate_refresh then
  self:_update_growrate()
  self.rate_refresh+=0.1
 end
 self.age+=self.growrate

 if (self.age<0.7) return

 if self.seeds==nil then
  self:_blossom()
 end

 local seed_si=max(1,min(4,ceil(
  (self.age-0.7)/0.3*5
 )))
 if seed_si!=self.seed_si then
  for s in all(self.seeds) do
   s.si=seed_si
  end
  self.seed_si=seed_si
 end

 if (self.age<1) return

 if self.preserve then
  self.skip_update=true
 else
  self:_dropseeds()
  return true
 end
end

tree_sprites={
 64,65,80,81,66,68,70,72,74,76,
 78,96,98,100,102,104,106
}

--draws the trunk
function tree:draw()
 local h=self:h()
 local x=self.x
 local y=flr(self.y*yscale)
 line(x-1,y,x-1,y-h,4)
 line(x,y,x,y-h,5)
 line(
  x-1,y-h,x,y-h,
  self.player.pal[6]
 )
end

function tree:draw_crown()
 if (self.age<=0.3) return

 local si=min(
  ceil((self.age-0.3)*40),17
 )
 pal(7,self.player.pal[6])
 if si<5 then
  spr(
   tree_sprites[si],
   self.x-4,
   self.y*yscale-8
  )
 else
  spr(
   tree_sprites[si],
   self.x-8,
   self.y*yscale-11,
   2,2
  )
 end
 pal(0)
end

function draw_treetop(unit)
 if istree(unit) then
  unit:draw_crown()
 end
end


-->8
--players

player={}
player.__index=player

function player:new(o)
 assert(o.pal!=nil)

 setmetatable(o,self)

 o.seeds={}
 o.trees={}
 o.fruit={}

 return o
end

function player:_listfor(obj)
 if isseed(obj) then
  if obj.grid==grid then
   return self.seeds
  end
  assert(obj.grid==hgrid)
  return self.fruit
 end
 if istree(obj) then
  return self.trees
 end
end

function player:unit_added(obj)
 if (obj.player!=self) return

 local l=self:_listfor(obj)

 add(l,obj)
 obj._pi=#l

 return true
end

function player:unit_removed(
 obj
)
 if (obj.player!=self) return

 local l=self:_listfor(obj)
 assert(l[obj._pi]==obj)

 local last=deli(l)
 if obj!=last then
  last._pi=obj._pi
  l[obj._pi]=last
 end

 return true
end

--human player
hplayer={}
extend(hplayer,player)
hplayer.__index=hplayer

function hplayer:new(o)
 o=player.new(self,o)
 setmetatable(o,self)

 o.selected=nil
 o.cx=grid.nrows*4
 o.cy=grid.ncols*4
 o.cursor_moving=true

 o.total_trees=0

 o._up={
  [o.trees]=o.fruit,
  [o.fruit]=o.seeds,
  [o.seeds]=nil
 }
 o._down={
  [o.trees]=nil,
  [o.fruit]=o.trees,
  [o.seeds]=o.fruit
 }

 return o
end

function hplayer:_unselect()
 self.selected=nil
end

function hplayer:_select(obj)
 if obj!=nil then
  assert(self.selected==nil)
  self.selected=obj
  self.cursor_moving=true
 end
end

function hplayer:unit_added(obj)
 if player.unit_added(
  self,obj
 ) then
  if istree(obj) then
   self.total_trees+=1
  end

  if self.selected==nil then
   self:_select(obj)
  end
 end
end

function hplayer:unit_removed(
 obj
)
 if (
  player.unit_removed(self,obj)
  and obj==self.selected
  and obj.grid!=hgrid
 ) then
  self:_unselect()
  self:_select(
   self:_find_closest(
    obj.x,obj.y,self.trees,
    pred_true,vlen
   )
  )
 end
end

--l_ini: initial search scope
--pred: optional filter on
--      objects to consider
--dist: distance function
function hplayer:_find_closest(
 x,y,l_ini,pred,dist,search_all
)
 local dmin=1000
 local closest=nil

 local search=function(l)
  for obj in all(l) do
   if pred(obj) then
    local d=dist(
     obj.x-x,obj.y-y
    )
    if d<=dmin then
     dmin=d
     closest=obj
    end
   end
  end
 end

 --search initial scope (which
 --may be a subset, e.g. only
 --seeds)
 local l=l_ini
 while l!=nil do
  search(l)
  l=self._up[l]
 end

 --expand the scope downwards
 --until something is found
 l=self._down[l_ini]
 while l!=nil and (
  closest==nil or search_all
 ) do
  search(l)
  l=self._down[l]
 end

 return closest
end

function hplayer:_find_next(
 dx,dy,search_all
)
 local sel=self.selected

 local pred=function(obj)
  if (obj==sel) return false

  local vx=obj.x-self.cx
  local mx=vx*dx
  if (mx<0) return false

  local vy=obj.y-self.cy
  local my=vy*dy
  if (my<0) return false

  --direction matches

  --check if object is inside
  --the "extended" quadrant
  if dx!=0 then
   return abs(vx*2)>abs(vy)
  else
   return abs(vy*2)>abs(vx)
  end

  return true
 end

 local dist
 if dy!=0 then
  dist=function(dx,dy)
   return abs(dy*0.25)+abs(dx)
  end
 else
  dist=function(dx,dy)
   return abs(dx*0.25)+abs(dy)
  end
 end

 local nxt=self:_find_closest(
  self.cx,self.cy,self.seeds,
  pred,dist,search_all
 )

 return nxt
end

--try to move the cursor
function hplayer:_try_move(
 dx,dy,search_all
)
 local nxt=self:_find_next(
  dx,dy,search_all
 )

 if nxt!=nil then
  self:_unselect()
  self:_select(nxt)
  sfx(12)
 else
  sfx(13)
 end
end

function hplayer:_can_root_obj(
 obj,ignore_barren
)
 return (
  not self.cursor_moving
  and isseed(obj)
  and obj.grid==grid
  and obj:can_root(
   ignore_barren
  )
 )
end

function hplayer:update_cursor()
 local sel=self.selected
 if (sel==nil) return

 if self.cursor_moving then
  self.cx=0.30*self.selected.x
   +0.70*self.cx
  self.cy=0.30*self.selected.y
   +0.70*self.cy
  self.cursor_moving=vlen(
   self.cx-sel.x,
   self.cy-sel.y
  )>2
 else
  self.cx=sel.x
  self.cy=sel.y
 end
end

_buttons={⬆️,➡️,⬇️,⬅️}
_dx={0,1,0,-1}
_dy={-1,0,1,0}
function hplayer:update()
 for i,b in pairs(_buttons) do
  if btnp(b) then
   self:_try_move(
    _dx[i],_dy[i],btn(❎)
   )
  end
 end

 if btnp(🅾️) then
  --allow rooting on barren.
  --this will destroy the seed
  --which can make way for
  --another and discourages
  --root spamming
  if not (
   self:_can_root_obj(
    self.selected,true
   )
   and self.selected:root(true)
  ) then
   sfx(13)
  end
 end

 self:update_cursor()
end

function hplayer:draw()
 --selection arrow
 local sel=self.selected
 if (sel==nil) return

 pal(6,9)
 local ymin=(
  istree(sel) and sel:h()+1
  or sel.h+sel.si
 )

 spr(
  self:_can_root_obj(sel)
   and 6 or 7,
  self.cx-4,
  flr(self.cy*yscale)-ymin-9
 )
 pal(0)
end

--computer player
cplayer={}
extend(cplayer,player)
cplayer.__index=cplayer

function cplayer:new(o)
 o=player.new(self,o)
 setmetatable(o,self)

 o.switch_count=0
 o.selected_idx=1
 o.root_cooldown=0
 o:_nxt_rooting()

 return o
end

function cplayer:_nxt_rooting()
 self.root_age=0.2+rnd(0.6)
end

--returns true iff the player
--is allowed to start a root
--action (ignoring if current
--seed can root)
function cplayer:can_root()
 return self.root_cooldown<=0
end

function cplayer:try_root(obj)
 if (
  self:can_root()
  and obj:root()
 ) then
  self.root_cooldown=90
  return true
 end
end

function cplayer:update()
 self.root_cooldown-=1

 local ns=#self.seeds
 if (ns==0) return

 self.switch_count-=1
 if self.switch_count<0 then
  self.selected_idx+=1
  self.switch_count=30
 end

 if self.selected_idx>ns then
  self.selected_idx=1
 end

 local s=self.seeds[
  self.selected_idx
 ]
 if ((
   s.age>=self.root_age
   or not s.moving
   or s:approaching_water()
   or grid:isgoal(s.x,s.y)
  ) and self:try_root(s)
 ) then
  self:_nxt_rooting()
 end
end

-->8
--main

function _init()
 pal({
  [1]=-16,--dark brown (bg)
  [8]=-8, --dark red
  [5]=-11,--dark grey (tree)
  [10]=-5,--med. green
  [6]=1   --blue
 },1)

 title=title:new()
 stats=stats:new()
 levelmenu=levelmenu:new()

 scene=title
end

game={}
function game:new(level)
 local o=setmetatable({},self)
 self.__index=self

 o:load_level(level)
 o.start=time()
 o.time_taken=0

 return o
end

function game:load_level(level)
 local ld=level_defs[level]
 self.level=level

 grid=cellgrid:new({
  mx=ld.mapdef[1],
  my=ld.mapdef[2],
  ncols=ld.mapdef[3],
  nrows=ld.mapdef[4]
 })
 hgrid=cellgrid:new({
  ncols=grid.ncols,
  nrows=grid.nrows
 })

 self.players={}
 local trees={}
 for i,p in pairs(ld.plyrs) do
  local is_human=(i==1)
  local plyr={
   pal=player_pals[i],
   use_sfx=is_human
  }
  if is_human then
   plyr=hplayer:new(plyr)
  else
   plyr=cplayer:new(plyr)
   if ld.weeds then
    plyr.seed_si_delta=16
    plyr.seedspeed=0.2
    plyr.treemaxseeds=2
   end
  end
  add(self.players,plyr)
  grid:add_observer(plyr)
  hgrid:add_observer(plyr)

  local t=tree:new(
   p[1],p[2],{player=plyr}
  )
  t.age=0.7
  add(trees,t)
 end

 self.goal=level_goal(
  level,self.players
 )
 grid:add_observer(self.goal)

 for t in all(trees) do
  grid:add(t)
 end

 maxgrowrate=(
  ld.maxgrowrate or
  default_maxgrowrate
 )

 self.anim=cowrap(
  "gamestart",gamestart_anim,
  self
 )
 self.dialog={y=-32}
 local si=level_goal_type(
  level
 )
 local name=ld.name
 local hw=#name*4+12
 self.anim.draw=function ()
  local y=self.dialog.y
  rectfill(63-hw,y,64+hw,y+20,1)

  printbig(name,84-hw,y+5,4)
  sspr(
   48+8*si,8,8,8,
   66-hw,y+3,16,16
  )
 end
end

function game:update()
 if self.anim!=nil then
  if coinvoke(self.anim) then
   self.anim=nil
  end

  return
 end

 grid:update_units()

 for p in all(self.players) do
  p:update()
 end

 local end_sfx=8
 local human=self.players[1]
 local winner=self.goal.winner
 self.time_taken=time()-self.start

 local msg
 if self.time_taken<0 then
  msg="timed out"
 elseif winner!=nil then
  if winner==human then
   stats:mark_done(
    self.level,
    self.time_taken,
    human.total_trees
   )
   local s=stats:get_stats(
    self.level
   )
   self.time_hi=(
    s.time_taken==self.time_taken
   )
   self.tree_hi=(
    s.total_trees==human.total_trees
   )
   msg="you did it!"
   end_sfx=4
  else
   msg="beaten by bots"
  end
 elseif (
  human.selected==nil
 ) then
  msg="game over"
 end

 if msg!=nil then
  sfx(end_sfx)
  self.anim=cowrap(
   "gameend",gameend_anim
  )
  self.anim.draw=function ()
   print(msg,64-#msg*2,63,7)
  end
 end
end

function game:draw()
 cls(6)

 camera(
  grid.ncols*4-64,
  grid.nrows*3-70
 )

 --draw map and units on ground
 grid:draw()

 --draw tree tops
 grid:visit_units(draw_treetop)

 --draw seeds on top of trees
 hgrid:draw_units(nil)

 local human=self.players[1]
 if self.anim==nil then
  human:draw()
 end

 camera()

 drawlogo()
 self.goal:draw()

 color(self.time_hi and 11 or 4)
 print_time(
  self.time_taken,97,120
 )

 color(self.tree_hi and 11 or 4)
 print_trees(
  human.total_trees,123,120
 )

 if self.anim!=nil then
  self.anim.draw()
 end
end

function _draw()
 scene:draw()
end

function _update60()
 scene:update()
end
-->8
title={}

function title:new()
 local o=setmetatable({},self)
 self.__index=self

 o.anim=cowrap(
  "title",title_anim,o
 )

 return o
end

function title:update()
 if self.anim!=nil then
  if coinvoke(self.anim) then
   self.anim=nil
  end
 end

 if (
  actionkeyp()
  or self.anim==nil
 ) then
  scene=levelmenu
 end
end

function title:_drawlogo(
 x0,y0,sx,sy,w,h
)
 for x=0,w do
  local dx=x0+x*2
  for y=0,h do
   local dy=y0+y*2
   local px=sget(sx+x,sy+y)
   if px!=15 then
    if (px&1>0) pset(dx,dy)
    if (px&2>0) pset(dx+1,dy)
    if (px&4>0) pset(dx,dy+1)
    if (px&8>0) pset(dx+1,dy+1)
   else
    rectfill(dx,dy,dx+1,dy+1)
   end
  end
 end
end

function title:_drawtrunk(y0)
 for y=y0,127 do
  local w=ceil((y-y0)/20)+2
  local xa=64-w
  local xb=64+w
  local x1=(xa*3+xb*2)/5
  local x2=(xa+xb*4)/5
  line(x1,y,x2,y,5)
  line(xa,y,flr(x1),y,4)
  line(ceil(x2),y,xb,y,1)
 end
end

function title:_drawseed(x,y,r)
 if (r<2) return

 pal(player_pals[1],0)
 pal(1,6,0)

 spr(r+190,x-3,y+2)

 pal(0)
end

function title:_drawbranch(
 y0,bl
)
 local db=(
  sin(bl/64)*4-sin(bl/80)*8
 )+3
 local ya,x1,x2
 for i=0,bl do
  local yb=y0+sin(i/80)*7.9+db
  ya=y0+sin(i/64)*3.9
  x1=63-i
  x2=64+i
  local y1=(ya+yb*3)/4
  local y2=(ya*3+yb)/4
  if i>2 then
   line(x1,y1,x1,y2,5)
   line(x1,yb,x1,ceil(y1),1)
   line(x2,yb,x2,ceil(y1),1)
  end
  if i>1 then
   line(x2,y1,x2,y2,5)
  end
  line(x1,flr(y2),x1,ya,4)

  line(x2,flr(y2),x2,ya,4)
 end

 spr(108,x1-8,ya-6,2,1)
 spr(108,x2-8,ya-6,2,1)

 self:_drawseed(
  x1,ya+1,self.seedr
 )
 self:_drawseed(
  x2,ya+1,self.seedr-0.5
 )
end

function title:draw()
 cls(6)

 local y0=self.logo.y
 rectfill(
  16,y0-4,111,y0+39,1
 )
 for f in all({
  {-1,0,5},{0,-1,5},
  {1,0,0},{0,1,0},{0,0,4}
 }) do
  local dx=f[1]
  local dy=f[2]
  color(f[3])

  self:_drawlogo(
   20+dx,y0+dy,0,16,43,7
  )
  self:_drawlogo(
   22+dx,y0+dy+20,45,16,42,7
  )
 end

 if self.seed then
  self:_drawseed(
   64,self.seed.y,self.seed.r
  )
  spr(108,56,self.seed.y-7,2,1)
 end

 if self.treeh>0 then
  local y0=127-self.treeh
  self:_drawtrunk(y0)

  if self.branchl>0 then
   self:_drawbranch(
    y0,self.branchl
   )
  else
   spr(108,56,y0-6,2,1)
  end
 end

 for i=0,15 do
  spr(110,i*8,120)
 end
end
__gfx__
00000000000000000000000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000006776000006600000000000000000000c0000c00000000000000000000000000000000000000000
00700700000000000000000000000000000000000006600000677600000660000000000000c00c0000c00c000000000000000000000000000000000060000000
000770000000000000000000000060000007650000676500006776000006600000000000000cc000000cc0000cc00cc000000000000660000600000000000060
0007700000000000000760000006750000066500006665006777777606666660000cc000000cc00000000000000cc00000c00c00006765000006670000000000
00700700000600000006500000005000000555000005500006777760006666000000000000000000000000000000000000000000006665000067650000066000
00000000000000000000000000000000000000000000000000677600000660000000000000000000000000000000000000000000000000000600006000000000
00000000000000000000000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000000000000060000006
00000000000000000000000000000000000000000000000044404440404040404444440000444000666000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000007700040404040440404000400040004000400606000000000000000000000000000000000000000000000
00000000000000000000000000000000000070000077770044404440404040400040000040444040666000006600000005000000000770000000000060000000
00666000000000000000000000000000000777000067750000000000440404000004000040404040000000006600000005000000007777000600000000000060
06000600000000000007700000077700000675000066650044404440404040400040000040444040000000006600000005000000006775000007760000000000
06060600000600000006500000066500000060000006600040404040400000000400040004000400000000000000000000000000006665000067750000077000
06000600000000000000000000000000000000000000000044404440400000004444440000444000000000000000000000000000000000000600006000000000
00666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000006
fffff40008fff408fff40fffffff000ffffffff8fff4002fffff4000fffff0ff408ff0008ff40fff0f4000ff4404400040404000444440000444000011155111
2ff02f400f102f0f102f0f00f00f000f00ff00ff102f0002ff02f400f000f0fffcfff000ffff02f10ff400f14404400044040000040040004000400015555551
0ff002f00f000f0f000f0000f40f000f00ff00ff000f0000ff002f00f00000f2fff1f000f12f00f00fff40f00000000040404000004000004040400055555555
0ff008f00f000f0f000f0000ff00000000ff000f000f0000ff008f00ffff00f02f10f000f00f00f00f2ff4f04404400040000000040040004000400055555555
0fffff500f500f0f400f0000ff00000000ff000f500f0000fffff500ff0008f00f00f400ffff40f00f42fff04404400040000000444440000444000015555551
8ff002f00ff00f0ff00f0008ff00000000ff400ff00f0000ff000f40ff000ff08f00ff08f12ff0f40ff02ff40000000000000000000000000000000001155110
fff408f40ff48f0ff48f008fff40000008fff40ff48f0008ff408ff4ff408ff0ff40ff4ff00ff8ff4ff002ff0000000000000000000000000000000000000000
ffff0ffffffff9fffffffffffff400008fffff4bfff1008ffff0fffffffffff0fff0fffff00ffffffff508ff0000000000000000000000000000000010000001
77777777777777777777777777777777777777777777777777777777711551175555555555555551555555515555555577777777777777777757757777777777
77777777777777777777777777777777777777777777777777777777155555515555555155555551555555515555555177777777777777777557755755555555
11001111001101001551115100000000666666661111111116666661555555555555555555555551555555515555555555555555555555555556655511111111
11111100110000111110551100000000666666666666666666666666555555555555555155555551555555515555555155555551555555555556655500000000
01111111001110005155100166666666666666666666666666666666155555515555555555555551555555515555555555555555555555555556655555555555
11101111011101101011155166666666666666666666666666666666011551101111111151151151111111115115115155555551555555555556655555555555
11111001100001001105511166666666666666666666666666666666000000000000000000000000000000000000000055555555555555555516615555555555
10011111000110115511115566666666666666666666666666666666100000010000000000000000000000000000000051515151555555555166661555555555
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000040000400000000000000000000000000000000000000000000000000004400000004000000440000000400000074000000040000007400000004000
00404400054044500004000000000000004400000000040000440000000004000044500000005400004450000000540000445000000057000044500000005700
00577500005775000005400000004000005540000000440000554000000044000055400000004440005540000000444000554000000044400455400000004440
00445400004454000000540000445000000054000044550000005400004455000000540000445550000054000044555000005400004455500500540000445550
00550500045505400000054044550000000005404455000000000540445500000000054044550000000005404455000000000540445500000000054044550000
00000000050000500000005775000000000000577500000000000057750000000000005775000000000000577500000000000057750000000000005775000000
00000000000000000000004454000000000000445400000000000044540000000000004454000000000000445400000000000044540000000000004454000000
40000000400000000000445505400000000044550540000000004455054000000000445505400000000044550540000000004455054000000000445505400000
54000044540000440004550000540000044455000054000004445500005400000444550000540000044455000054000004445500005400000444550000540040
05404455054044550005000000054000055500000005440005550000000544000545000000054400054500000005440005750000000544000575000000054450
00577500005775000000000000005000000000000000550000000000000055000054000000044500005400000004450000540000000475000054000000047500
00445400004454000000000000000000000000000000000000000000000000000005000000055000000500000005500000050000000550000005000000055000
44550540445505400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55000054550000540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000005000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000040000000000000004000000000000000440004000000000044400400000000004470070000000000000000000000000000000000000
00074000000040000007450000044000000745000004400000074550005440000007455500544000000745550054400000000000000000000000000000000000
00445000000057000044500000055700004450000005570000445000000557000044500000055700004450000005570000000000000000000000000000000000
0455400000004440045540000000444004554000000044400455400000004440045540000000444004554000000044400003330000bbb0000000000000000000
050054000044555405005400004455544500540000445554450054000044555445005400004455547500540000445554000333300bbb33000b0000b000000000
000005404455000500000540445500055000054044550005500005404455000550000540445500045000054044550007000333300b333300030b00b000000000
000000577500000000000057750000000000005775000000000000577500000000000057750000050000005775000005000033330b330000b30300b300000000
00000044540000000000004454000000000000445400000000000044540000004000004454000000700000445400000000000033033000003333333300000000
40004455054000004000445505400000400044550540000440004455054000044000445505400004400044550540000700000000000000000000000000000000
54445500005400405444550000540040544455000054004554445500005400455444550000540045544455000054004500000000000000000000000000000000
05750000000544500575000000054450057500000005445005750000000544500575000000054450057500000005445000000000000000000000000000000000
00540000000475000054400000047500005440000004750000544000000475000054400000047500005440000004750000000000000000000000000000000000
00050000000550000005500000455000000550000045500000055400044550000005540044455000000557007445500000000000000000000000000000000000
00000000000000000000000000500000000000000050000000000500055000000000050055500000000005005550000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000004333333333333333333333333333334300000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00065000000060000006600000665000006665000066500000666500000000000000000000000000000000000000000000000000000000000000000000000000
00055000000665000067650006766500067665500676650006766650000000000000000000000000000000000000000000000000000000000000000000000000
00000000000050000066550006666500066765506776655067776655000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000005500005665500066655506666655066766655000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000555000055555505666555066666555000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000005555000555550056665555000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055500005555550000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000555500000000000000000000000000000000000000000000000000000000000000000000000000
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1111111111111111
1111111111111111gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1111111111111111
1111111111111111gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1111111111111111
1111111111111111ggggllllllllllggggggggggllllllggggggllllllggggllllllllllllllggggggllllllllllllllllggllllllgggggg1111111111111111
1111111111111111gggl44444444440ggggggggl4444440ggggl4444440ggl444444444444440ggggl44444444444444440l4444440ggggg1111111111111111
1111111111111111gggl444444444440ggggggl444444440ggl444444440gl444444444444440ggggl44444444444444440444444440gggg1111111111111111
1111111111111111gggg0444440004440ggggl44400004440l44400004440l440000440000440ggggl440000444400004444400004440ggg1111111111111111
1111111111111111ggggg044440gg04440gggl440gggg0440l440gggg0440l440ggl440ggl440ggggl440ggl44440ggl44440gggg0440ggg1111111111111111
1111111111111111gggggl44440ggg04440ggl440ggggl440l440ggggl440g00gggl440ggl440ggggl440ggl44440ggl44440ggggl440ggg1111111111111111
1111111111111111gggggl44440gggg0440ggl440ggggl440l440ggggl440ggggggl4440gl440ggggl440ggl44440ggl44440ggggl440ggg1111111111111111
1111111111111111gggggl44440ggggl440ggl440ggggl440l440ggggl440ggggggl44440g00gggggg00gggl44440ggg00440ggggl440ggg1111111111111111
1111111111111111gggggl44440llll4440ggl440ggggl440l440ggggl440ggggggl44440ggggggggggggggl44440ggggl440ggggl440ggg1111111111111111
1111111111111111gggggl444444444440gggl4440gggl440l440ggggl440ggggggl44440ggggggggggggggl44440ggggl4440gggl440ggg1111111111111111
1111111111111111gggggl444444444440gggl4440gggl440l4440gggl440ggggggl44440ggggggggggggggl44440ggggl4440gggl440ggg1111111111111111
1111111111111111gggggl4444000004440ggl44440ggl440l44440ggl440ggggggl44440ggggggggggggggl44440ggggl44440ggl440ggg1111111111111111
1111111111111111ggggl444440gggg0440ggl44440ggl440l44440ggl440gggggl444440ggggggggggggggl444440gggl44440ggl440ggg1111111111111111
1111111111111111gggl4444440ggggl440ggl44440ggl440l44440ggl440ggggl4444440ggggggggggggggl4444440ggl44440ggl440ggg1111111111111111
1111111111111111gggl44444440ggl44440ll444440l4440l444440l4440llll444444440ggggggggggggl444444440gl444440l4440ggg1111111111111111
1111111111111111gggl444444440l444444444444444440444444444444444444444444440ggggggggggl44444444440l4444444440gggg1111111111111111
1111111111111111gggl444444440l4444444444444444044444444444444444444444444440ggggggggl4444444444440044444440ggggg1111111111111111
1111111111111111gggg00000000gg0000000000000000g0000000000000000000000000000gggggggggg000000000000gg0000000gggggg1111111111111111
1111111111111111gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1111111111111111
1111111111111111gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1111111111111111
1111111111111111ggggggggglllllllllllggggggggllllllllllggllllggggggllllggggggggllllggggllllllggllggggggggllllgggg1111111111111111
1111111111111111ggggggggl444444444440ggggggl44444444440l44440ggggl44440ggggggl44440ggl4444440l440ggggggl44440ggg1111111111111111
1111111111111111ggggggggg0444444444440gggggl44444444440l444440ggl444440gggggl4444440gl4444440l4440gggggl44440ggg1111111111111111
1111111111111111gggggggggg0444440004440ggggl44000000440l4444440l4444440ggggl444444440g044440gl44440ggggl4440gggg1111111111111111
1111111111111111ggggggggggg044440gg04440gggl440ggggl440l444444444444440ggggl444444440gg0440ggl444440gggl440ggggg1111111111111111
1111111111111111gggggggggggl44440ggg04440ggl440ggggg00gl440444444440440ggggl444004440ggl440ggl4444440ggl440ggggg1111111111111111
1111111111111111gggggggggggl44440gggg0440ggl440lllllgggl44004444440l440ggggl440gg0440ggl440ggl44444440gl440ggggg1111111111111111
1111111111111111gggggggggggl44440ggggl440ggl444444440ggl440g044440gl440ggggl440ggl440ggl440ggl440444440l440ggggg1111111111111111
1111111111111111gggggggggggl44440llll4440ggl444444440ggl440gg0440ggl440ggggl440lll440ggl440ggl4400444440440ggggg1111111111111111
1111111111111111gggggggggggl444444444440gggl44440000gggl440ggl440ggl440ggggl444444440ggl440ggl440g044444440ggggg1111111111111111
1111111111111111gggggggggggl444444444440gggl44440gggggl4440ggl440ggl4440gggl4444444440gl440ggl4440g04444440ggggg1111111111111111
1111111111111111gggggggggggl4444000000440ggl44440ggggl44440ggl440ggl44440ggl44400444440l440ggl44440g0444440ggggg1111111111111111
1111111111111111gggggggggggl44440ggggl4440gl44440ggggl44440gl4440ggl44440gl4440gg044440l4440gl44440gg0444440gggg1111111111111111
1111111111111111gggggggggggl44440ggggl44440l44440ggggl44440l44440ggl44440l44440ggl44440l44440l44440ggg0444440ggg1111111111111111
1111111111111111ggggggggggl4444440ggl4444440444440lll444440l444440gl44444044440ggl44440444444044440gggg044440ggg1111111111111111
1111111111111111gggggggggl444444440l44444444444444444444440l4444440l44444444440ggl444444444444444440gggl44440ggg1111111111111111
1111111111111111ggggggggl4444444440l44444444444444444444440l4444440l44444444440ggl444444444444444440ggl444440ggg1111111111111111
1111111111111111ggggggggg000000000gg0000000000000000000000gg000000gg0000000000gggg00000000000000000gggg00000gggg1111111111111111
1111111111111111gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1111111111111111
1111111111111111gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1111111111111111
1111111111111111gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg1111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111113331111bbb111444444444444444111111111111111111444444444444444113331111bbb1111111111111111111111111111
111111111111111111111111111333311bbb334444444444444444444411111111111144444444444444444444333311bbb33111111111111111111111111111
111111111111111111111111111333311b333344lllllllllllll4444444411111144444444lllllllllllll44333311b3333111111111111111111111111111
111111111111111111111111111133334b33llllllggglllllllllll4444444114444444lllllllllllllllllll33334b3311111111111111111111111111111
11111111111111111111111111111133433llggggggggggggggllllllll4444444444llllllllggggggggggggglll33433111111111111111111111111111111
11111111111111111111111111111111llgggg111111111111gggglllllll444444lllllllgggg111111111111ggglll11111111111111111111111111111111
1111111111111111111111111111111ooo2111111111111111111ggglllll444llllllllggg111111111111111111gooo2111111111111111111111111111111
111111111111111111111111111111oeooo21111111111111111111ggglll444llllllggg11111111111111111111oeooo211111111111111111111111111111
11111111111111111111111111111oeeeoo2211111111111111111111gggl444llllggg111111111111111111111oeeeoo221111111111111111111111111111
11111111111111111111111111111ooeooo221111111111111111111111gg444llggg11111111111111111111111ooeooo221111111111111111111111111111
11111111111111111111111111111ooooo222111111111111111111111111444llgg111111111111111111111111ooooo2221111111111111111111111111111
111111111111111111111111111112ooo2222111111111111111111111111444llgg1111111111111111111111112ooo22221111111111111111111111111111
1111111111111111111111111111112222221111111111111111111111111444llgg111111111111111111111111122222211111111111111111111111111111
1111111111111111111111111111111222211111111111111111111111111444llgg111111111111111111111111112222111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111111444llgg111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111114444lllgg11111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111144444lllggg1111111111111111111111111111111111111111111111111111111111
1b1111b11b1111b11b1111b11b1111b11b1111b11b1111b11b1111b11b1444b4lblgggb11b1111b11b1111b11b1111b11b1111b11b1111b11b1111b11b1111b1
131b11b1131b11b1131b11b1131b11b1131b11b1131b11b1131b11b1131b44b4l3lbggb1131b11b1131b11b1131b11b1131b11b1131b11b1131b11b1131b11b1
b31311b3b31311b3b31311b3b31311b3b31311b3b31311b3b31311b3b34344b3b3l3ggb3b31311b3b31311b3b31311b3b31311b3b31311b3b31311b3b31311b3
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000010404040402020202020808020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
3b38383838383838383838383838393b38383838383838383838383838393c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434340000000000003434343434343434343434343434343434
3930313031303130313031303130393930313031303130313031303130393c303130313031303130313031303c3430313031303134313031303130343031303130313031303130313031343031303130313031303130313031303430303030303434343131313131340000000000003430313034303130343031303430313034
3931303130313031303130313031393931303130313031303130313031393c313031303130313031303130313c3431323232323034303232323231343130313031303130313031303130343130313031303130313031303130313430323232303d3d3d3132323231340000000000003431303134313031343130313431303134
3930313232323130313232323130393930313232323230323232323130393c30313232323c3c3c32323231303c343032323232313d313232323230343031303130313031303130313031343032323230313031303130323232303430323232303d3d3d3132323231340000000000003430313034303130343031303630313034
3931303232323031303232323031393931303232323239323232323031393c31303232323c3c3c32323230313c343132323232303d3032323232313431303130313031303130313031303431323232313038383a3031323232313430323232303d3d3d3132323231340000000000003433333334333333343333333433333334
3930313232323130313232323130393930313232323239323232323130393c30313232323c3c3c32323231303c3430323232323135313232323230343333333333333333333330313031343032323230313031303130323232303430303030303535353131313131340000000000003430313034303130343031303430313034
3931303130313031303130313031393931303232323239323232323031393c31303c3c3c3c3c3c3c3c3c30313c34313031303130343031303130313431303130313232323234313031303431303130313031303130313031303134333d3d3d33343434333d3d3d33340000000000003431303134313031343130313431303134
393031303130313031303130313039393031303838383b383838303130393c30313c3c3c3c3c3c3c3c3c31303c3433333d3d33333433333d3d3333343031303130323232323430313031343031303130313d3d3d31303130313034343d3d3d34343434343d3d3d34340000000000003430313034303130343031303430313034
3931303130313031303130313031393931303232323239323232323031393c31303c3c3c3c3c3c3c3c3c30313c3431303130313034303130313031343130313031323232323431303130343333333333333d3d3d33333333333334343d3d3d34343434343d3d3d34340000000000003433333334333333343333333433333334
3930313232323130313232323130393930313232323239323232323130393c30313232323c3c3c32323231303c3430323232323134313232323230343031303130323232323430313031343031303130313d3d3d3130313031303431313131313434343030303030340000000000003430313034303130343031303430313034
3931303232323031303232323031393931303232323239323232323031393c31303232323c3c3c32323230313c343132323232303d303232323231343130313033333333333431303130343130313031303130313031303130313431323232313d3d3d3032323230340000000000003431303134313031343130313431303134
3930313232323130313232323130393930313232323230323232323130393c30313232323c3c3c32323231303c343032323232313d313232323230343031303130313031303130313031343032323230313031303130323232303431323232313d3d3d3032323230340000000000003430313034303130343031303430313034
3931303130313031303130313031393931303130313031303130313031393c313031303130313031303130313c34313232323230353032323232313431303130313031303130313031303431323232313038383a3031323232313431323232313d3d3d3032323230340000000000003433333334333333343333333433333334
3930313031303130313031303130393930313031303130313031303130393c303130313031303130313031303c3430313031303134313031303130343031303130313031303130313031343032323230313031303130323232303431313131313535353030303030340000000000003430313034303130343031303430313034
38383838383838383838383838383a38383838383838383838383838383a3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3433333333333334333333333333343130313031303130313031303130343130313031303130313031303130313433333333333434343333333333340000000000003431303134313031343130313431303134
3434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343434343333333333333333333333333333343031303130313031303130313031303434343434343434343434343434343400000000003430313034303130343031303430313034
343232323232343434323232323234313132323131323231313232313134313131303131343431313031313134343031303d303130313031303130343434343434343434343434343434343333333333333333333333333333333434343434343130313034313031303400000000003433333334333333343333333433333334
343232323232343434323232323234313132323131323231313232313134313131303131343431313031313134343130313d31303130313031303134343031303d30313031303130313034343434343434343434343434343434343434343434303130313d303130313400000000003430313034303130343031303430313034
343232323232343434323232323234323231313232313132323131323234313131333030313130303331313134343031303d30313031303130313034343130313d31303130313031303134343c3c32323c3c32323c3c32323c3c343130313034313031303d313031303400000000003431303134313031343130313431303134
3432323232323d3d3d323232323234323231313232313132323131323234303033343030313130303433303034343333333533333333333331303134343031303d30313031303130313034343c3c32323c3c32323c3c32323c3c34303130313d3031303135303130313400000000003430313034303130343031303430313034
3432323232323d3d3d323232323234313132323131323231313232313134313130303333303033333030313134343130313d303130313034303130343433333335333333333333313031343432323c3c32323c3c32323c3c323234313031303d3130313034333031333400000000003433333334333333343333333433333334
343333333d3d3535353d3d33333334313132323131323231313232313134313130303434303034343030313134343031303d31303130313431303134343130313d303130313034303130343432323c3c32323c3c32323c3c32323430313031353031303134303130313400000000000000000000000000000000000000000000
343434343d3d3434343d3d34343434323231313232313132323131323234333331313030333330303131333334343130313d30313031303d30313034343031303d31303130313431303134343c3c32323c3c32323c3c32323c3c343130313034333d3d3334313031303400000000000000000000000000000000000000000000
343434343d3d3434343d3d34343434323231313232313132323131323234343431313030343430303131343434343031303531303130313d31303134343130313d30313031303d30313034343c3c32323c3c32323c3c32323c3c343031303134343d3d3434303130313400000000000000000000000000000000000000000000
3432323232323d3d3d323232323234313132323131323231313232313134313130303333303033333030313134343130313430313031303d30313034343031303531303130313d313031343432323c3c32323c3c32323c3c32323431303130343130313034313031303400000000000000000000000000000000000000000000
3432323232323d3d3d323232323234313132323131323231313232313134313130303434303034343030313134343031303433333333333533333334343130313430313031303d303130343432323c3c32323c3c32323c3c323234303130313d3031303134333130333400000000000000000000000000000000000000000000
343232323232353535323232323234323231313232313132323131323234303033333030313130303333303034343130313031303130313d31303134343031303433333333333533333334343c3c32323c3c32323c3c32323c3c34313031303d3130313034313031303400000000000000000000000000000000000000000000
343232323232343434323232323234323231313232313132323131323234313131343030313130303432323234343031303130313031303d30313034343130313031303130313d32323234343c3c32323c3c32323c3c32323c3c343031303135303130313d303130313400000000000000000000000000000000000000000000
343232323232343434323232323234313132323131323231313232313134313131303131333331313032323234343130313031303130313d31303134343031303130313031303d323232343432323c3c32323c3c32323c3c3232343333333334313031303d313031303400000000000000000000000000000000000000000000
343333333333343434333333333334313132323131323231313232313134313131303131343431313032323234343333333333333333333533333334343130313031303130313d323232343432323c3c32323c3c32323c3c32323434343434343031303135303130313400000000000000000000000000000000000000000000
000000000000000000000000000034333333333333333333333333333334333333333333343433333333333334000000000000000000000000000000343333333333333333333533333334343c3c32323c3c32323c3c32323c3c3434343434343333333334333333333400000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000343c3c32323c3c32323c3c32323c3c3400000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00020000256402564024630216301d620156200d6200a61006610056100361503600026051a6001960015600116000e6000860003600026050060000600006000060000600006000060000600006000060000600
01080000117501175011750000001075010750107501c7000e7500e7500e750007000c7500c7500c7500c7500c7500c7500c75000700007000070000700007000070000700007000070000700007000070000700
011000000555005550055500555504550045500455204555025500255202552025550055200552005520055200552005520055500500005000050000500005000050000500005000050000500005000050000500
000300001813018131181311813500100001001c1401c1411c1411c1311d1311d1311d1311d1211d1211d1251d100001000010000100001000010000100001000010000100001000010000100001000010000100
010a00001c7501c7501c7501c7551d7501d7501d7501d7551f7621f7621d7521d7521f7521f7521f7521f75500700007000070000700007000070000700007000070000700007000070000700007000070000700
010a00002c757327572c7573575500700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
01060000116401063009623006000b6000b6000860006600046000260002600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100001e0501a750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000505005050030500305000051000520004200042000320003200012000150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040000176111661112615106000060008614086150c6000c6030460313600136001260012600126001260011600116001160011600106001060010600106000f6000f6000f6000f6000e6000e6000e6000e600
01060000096131f000000000000011600106000960300000096030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800001c5511f5510070000700007000070000700107001070010700107000e7000e7000d7001270011700107000f7000e7000d7000c7000b7000a700097000870007700067000570500700007000070000700
010100003375030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100002775000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000121400d130101010f1010e1010d1010c1010b1010a1010910108101071050010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
01200000127240d721077110171100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100001154410530095250050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011c00000301406011080110a0110c0110e0111001111011120111301513005130052600027001270000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000a00001a5201d520215302453026540265000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
