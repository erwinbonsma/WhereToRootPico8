pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- where to root? v0.3
-- (c) 2023  eriban

--cartdata
vmajor=0
vminor=1

frate=30
seed_r=2.2
tree_r=3
max_r=max(seed_r,tree_r)
tree_h=5
branch_l=8
yscale=0.75
seeddrop_h=6

cellsz=8
roots_r=16
default_maxgrowrate=0.1/frate
maxgrowrate=default_maxgrowrate

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
 1,2,3,8,
 5,7,4,6,
 9,0,10,11,
 0,0,0,0,
 0,0,0,0
}

level_defs={{
 name="intro",
 data={
  mapdef={0,0,15,15},
  goals={{3,3,3,3},{9,9,3,3},{9,3,3,3},{3,9,3,3}},
  plyrs={{36,36}}
 }
},{
 name="walls",
 data={
  mapdef={15,0,15,15},
  goals={{3,3,4,4},{8,8,4,4},{8,3,4,4},{3,8,4,4}},
  plyrs={{40,40}}
 }
},{
 name="tiles",
 data={
  mapdef={30,0,15,15},
  goals={{3,3,3,3},{9,9,3,3},{9,3,3,3},{3,9,3,3}},
  plyrs={{36,36}}
 }
},{
 name="water",
 data={
  mapdef={45,0,15,15},
  goals={{2,2,4,4},{9,9,4,4},{9,2,4,4},{2,9,4,4}},
  plyrs={{32,32}}
 }
},{
 name="plane",
 data={
  mapdef={0,0,15,15},
  goals={{3,3,3,3},{9,9,3,3},{9,3,3,3},{3,9,3,3}},
  plyrs={{36,36},{84,36},{36,84},{84,84}}
 }
},{
 name="spiral",
 data={
  mapdef={59,0,16,16},
  goals={{6,6,4,4}},
  plyrs={{24,24}}
 }
},{
 name="duel",
 data={
  mapdef={74,0,17,17},
  goals={{2,3,3,3},{12,11,3,3},{12,3,3,3},{2,11,3,3}},
  plyrs={{68,22},{68,116}}
 }
},{
 name="bridges",
 data={
  mapdef={90,0,15,15},
  goals={{2,2,3,3},{10,10,3,3},{10,2,3,3},{2,10,3,3}},
  plyrs={{28,28}}
 }
},{
 name="islands",
 data={
  mapdef={0,15,15,15},
  goals={{1,1,5,5},{9,9,5,5},{9,1,5,5},{1,9,5,5}},
  plyrs={{28,28},{92,92},{92,28},{28,92}}
 }
},{
 name="checker",
 data={
  mapdef={14,15,16,16},
  target=8,
  plyrs={{64,64}},
  params={
   maxgrowrate=
    default_maxgrowrate*0.5
  }
 }
},{
 name="holey",
 data={
  mapdef={29,15,16,16},
  plyrs={{20,20}},
  goals={{12,12,3,3}}
 }
}}

--sprite flags
flag_goal=0
flag_wall=1
flag_water=2
flag_barren=3

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

mainmenu={}
function mainmenu:new()
 local o=setmetatable({},self)
 self.__index=self

 o.row=1
 o.rows={
  "play",
  "stats",
  "help"
 }

 return o
end

function mainmenu:update()
 if btnp(⬆️) then
  self.row=
   (self.row+1)%#self.rows+1
 end
 if btnp(⬇️) then
  self.row=1+self.row%#self.rows
 end
 if btnp(❎) then
  if self.row==1 then
   scene=levelmenu
  end
  if self.row==2 then
   scene=stats
  end
 end
end

function mainmenu:draw()
 cls(1)

 for n,s in pairs(self.rows) do
  color(n==self.row and 11 or 3)
  print(s,20,n*8+60) 
 end
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
   dset(l*2,1000)
   dset(l*2+1,6000)
  end
 end

 dset(0,vmajor)
 dset(1,vminor)

--temp:xplicit clear new levels
-- dset(22,1000)
-- dset(23,6000)

 return o
end

function stats:mark_done(
 level,time_taken,total_trees
)
 local cur=self:get_stats(level)
 dset(level*2,
  min(cur.total_trees,
   min(total_trees,999)))
 dset(level*2+1,
  min(cur.time_taken,
   min(time_taken,5999)))
end

function stats:is_done(level)
 return dget(level*2)<1000
end

function stats:get_stats(level)
 return {
  total_trees=dget(level*2),
  time_taken=dget(level*2+1)
 }
end

function stats:stats_str(level)
 local s=self:get_stats(level)
 local arrow=" \^:08083e1c08000000"
 return "⧗"..time_str(
  s.time_taken
 )..arrow..s.total_trees
end

function stats:update()
 if btnp(❎) then
  scene=mainmenu
 end
end

function stats:draw()
 cls(1)
 color(3)
 for n,ld in pairs(level_defs) do
  print(ld.name,0,n*6)
  print(self:stats_str(n),32,n*6)
 end
end

levelmenu={}

function levelmenu:new(
 stats
)
 local o=setmetatable({},self)
 self.__index=self

 o.stats=stats
 o.grid=cellgrid:new({
  mx=111,my=0,nrows=17,ncols=17
 })

 o.hbridges={}
 for b in all({0,1,4,5,6}) do
  o.hbridges[b]=true
 end
 o.vbridges={}
 for b in all({2,3,4,6,7}) do
  o.vbridges[b]=true
 end

 for p=19,0,-1 do
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
     odd and 16 or 17
    )
   end
  end
 end

 self.pos=pos
 self.cx=pos%4
 self.cy=flr(pos/4)
 self.lvl=levelmenu_pos[pos+1]
 self.tree=self.stats:is_done(
  self.lvl
 )

 for x=1,3 do
  for y=1,3 do
   mset(
    self.grid.mx+x+self.cx*4,
    self.grid.my+y+self.cy*4,
    18
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
  if self.stats:is_done(
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
 else
  sfx(7)
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
 if btnp(🅾️) then
  scene=mainmenu
 end
 if btnp(❎) then
  scene=game:new(
   self.lvl,self.stats
  )
  sfx(3)
 end

 if (
  not self.tree and
  self.stats:is_done(self.lvl)
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
   spr(f and 29 or 30,x+16,y)
   spr(f and 21 or 22,x+16,y+6)
  end

  if self.vbridges[p] then
   local f=self:_can_move(
    p,p+4
   )
   spr(f and 29 or 31,x,y+12)
  end
 end

 palt()
 self.grid:visit_units(
  draw_treetop
 )

 camera()

 print("where to root?",37,2,4)

 local name=level_defs[
  self.lvl
 ].name
 print("level: "..name,4,120,9)

 if self.stats:is_done(
  self.lvl
 ) then
  local s=self.stats:stats_str(
   self.lvl
  )
  print(
   s,185-#s*4,120,9
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
 obj.grid=nil

 for o in all(self.observers) do
  o:unit_removed(obj)
 end
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
 local mx=x%cz
 local my=y%cz
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
 local x0=args[1]
 local y0=args[2]
 local w=args[3]
 local h=args[4]
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

 return o
end

function areagoal:_is_done(
 counts
)
 for area in all(self.areas) do
  if (counts[area]==0) return false
 end
 return true
end

function areagoal:unit_added(
 unit
)
 if (not istree(unit)) return

 local plyr=unit.player
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
 local c=self.counts
 if unit.area!=nil then
  c[unit.player][unit.area]-=1
  unit.area=nil
 end
end

function areagoal:draw()
 local x=10
 local y=2
 local c=self.counts
 for p in all(self.players) do
  y=2
  pal(p.pal)
  spr(4,x,y-1)
  x+=7
  for n,a in pairs(self.areas) do
   print(
    c[p][a],
    x+flr((n%4)/2)*4,
    y+((n+1)%2)*6,6
   )
  end
  x+=12
  pal(0)
 end
end

function areagoal:draw_debug()
 for x=0,15 do
  for y=0,19 do
   for a in all(self.areas) do
    if a(x,y) then
     rect(x*8,y*6,x*8+7,y*6+5,7)
    end
   end
  end
 end
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
 local x=10
 local y=2
 local c=self.counts
 for p in all(self.players) do
  y=2
  pal(p.pal)
  spr(4,x,y-1)
  x+=7
  print(
   self.counts[p],x,y
  )
  x+=12
  pal(0)
 end
end

-->8
--animations

function seeddrop_anim(args)
 local s=args[1]
 local kills=args[2]
 local use_sfx=args[3]

 s.vh=0
 while s.h>0 do
  s.vh-=0.04
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
 wait(4)

 while s.si<15 do
  s.si+=1
  wait(4)
 end

 s.destroy=true
end

function seedsplat_anim(args)
 local s=args[1]
 local use_sfx=args[2]

 s.vh=0
 while s.h>2 do
  s.vh-=0.04
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
  s.x+=f.x*s.speed/frate
  s.y+=f.y*s.speed/frate
  yield()
  f=grid:water_force(
   s.x,s.y,s.r
  )
  s.vh=0
 end

 s.h0=-3
 while s.h>-6 do
  s.vh-=0.04
  s.h+=s.vh
  yield()
 end
 s.h=-3
 s.vh=nil

 if (use_sfx) sfx(9)
 s.si=8
 wait(2)

 while s.si<12 do
  s.si+=1
  wait(2)
 end

 s.destroy=true
end

function seedroot_anim(args)
 local s=args[1]
 local t=args[2]
 local use_sfx=args[3]

 if (use_sfx) sfx(11)

 s.vh=0.5
 while s.h>0 or s.vh>0 do
  s.vh-=0.04
  s.h+=s.vh
  yield()
 end
 yield()

 if (use_sfx) sfx(15)
 local steps=s.si
 for i=0,s.si-1 do
  s.h=-i
  wait(10)
 end

 if s:_tree_fits(t) then
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

function gameend_anim(args)
 local g=args[1]
 local msg=args[2]

 g.msg=msg

 wait(90)

 scene=mainmenu
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
 o.growrate=0.06/frate
 o.speed=o.speed or 6
 o.moving=true
 o.selected=false
 o.anim=nil
 o.si=o.si or 4
 o.h0=0 --ground level

 return o
end

--check if tree fits. it may
--hit seeds, but not another
--tree
function seed:_tree_fits(t)
 local fits=true
 local visitor=function(obj)
  if istree(obj) then
   fits=false
  end
 end

 grid:visit_hits(
  t.x,t.y,t.r,visitor,self
 )

 return fits
end

function seed:can_root()
 return (
  self.anim==nil or
  self.anim.name=="rot"
 ) and
 not grid:isbarren(
  self.x,self.y
 ) and
 not grid:iswater(
  self.x,self.y
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

function seed:root()
 if not self:can_root() then
  return false
 end

 local t=tree:new(
  self.x,self.y,{
   player=self.player
  }
 )

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

 if (not self.moving) return

 local v=self.speed/frate
 local dx=self.dx*v
 local dy=self.dy*v
 if grid:fits(
  self.x+dx,self.y+dy,self.r,self
 ) then
  self.x+=dx
  self.y+=dy
  grid:moved(self)

  if grid:iswater(
   self.x,self.y
  ) then
   self.anim=cowrap(
    "waterdrop",
    waterdrop_anim,self,
    self.player.use_sfx
   )
  end
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
  spr(self.si,self.x-4,y)
 else
  sspr(
   self.si*8,0,8,
   6+self.h-self.h0,
   self.x-4,y
  )
 end

 if self.selected then
  spr(
   self.player:can_root()
   and 5 or 6,
   self.x-3,y-7
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
 o=setmetatable(o or {},self)
 self.__index=self

 o.x=x
 o.y=y
 o.r=o.r or tree_r
 o.maxseeds=o.maxseeds or 3

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

function tree:update()
 if self.destroy then
  return true
 end
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
 192,193,208,209,
 194,196,198,200,202,204,206,
 224,226,228,230,232,234
}

--draws the trunk
function tree:draw()
 local h=flr(
  min(self.age,0.25)*4*tree_h
 )

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
 o.total_trees=0
 o.root_cooldown=0

 return o
end

function player:_listfor(obj)
 if isseed(obj) then
  return self.seeds
 end
 if istree(obj) then
  return self.trees
 end
end

function player:unit_added(obj)
 if obj.player!=self then
  return false
 end

 local l=self:_listfor(obj)

 add(l,obj)
 obj._pi=#l

 if istree(obj) then
  self.total_trees+=1
 end

 return true
end

function player:unit_removed(
 obj
)
 if obj.player!=self then
  return false
 end

 local l=self:_listfor(obj)
 assert(l[obj._pi]==obj)

 local last=deli(l)
 if obj!=last then
  last._pi=obj._pi
  l[obj._pi]=last
 end

 return true
end

--returns true iff the player
--is allowed to start a root
--action (ignoring if current
--seed can root)
function player:can_root()
 return self.root_cooldown<=0
end

function player:try_root(seed)
 if (
  self:can_root()
  and seed:root()
 ) then
  self.root_cooldown=15
  return true
 end

 return false
end

function player:update()
 self.root_cooldown-=1
end

--human player
hplayer={}
extend(hplayer,player)
hplayer.__index=hplayer

function hplayer:new(o)
 o=player.new(self,o)
 setmetatable(o,self)

 o.selected=nil

 return o
end

function hplayer:_unselect()
 if self.selected!=nil then
  self.selected.selected=false
  self.selected=nil
 end
end

function hplayer:_select(obj)
 if obj!=nil then
  assert(self.selected==nil)
  self.selected=obj
  obj.selected=true
 end
end

function hplayer:unit_added(obj)
 if (
  player.unit_added(self,obj)
  and isseed(obj)
  and #self.seeds==1
 ) then
  self:_select(obj,true)
 end
end

function hplayer:unit_removed(
 obj
)
 if (
  player.unit_removed(self,obj)
  and obj==self.selected
 ) then
  self:_unselect()
  self:_select_closest(
   obj.x,obj.y
  )
 end
end

function hplayer:_select_closest(
 x,y
)
 local dmin=1000
 local nearest=nil
 for s in all(self.seeds) do
  local d=vlen(s.x-x,s.y-y)
  if d<dmin then
   dmin=d
   nearest=s
  end
 end
 self:_select(nearest)
end

function hplayer:_find_next(
 dx,dy
)
 local sel=self.selected
 local nxt=nil
 local dmin=2000
 for s in all(self.seeds) do
  if s!=sel then
   local vx=s.x-sel.x
   local vy=s.y-sel.y
   local mx=vx*dx
   local my=vy*dy
   if mx>=0 and my>=0 then
    --direction matches
    local d=abs(mx)+abs(my)
    if (
     (dx!=0)==(abs(vx)<=abs(vy))
    ) then
     --not in target quadrant
     d+=1000
    end

    if d<dmin then
     dmin=d
     nxt=s
    end
   end
  end
 end

 return nxt
end

--try to move the cursor
function hplayer:_try_move(
 dx,dy
)
 local nxt=nil
 if self:can_root() then
  nxt=self:_find_next(dx,dy)
 end

 if nxt!=nil then
  self:_unselect()
  self:_select(nxt)
  sfx(12)
 else
  sfx(13)
 end
end

function hplayer:update()
 player.update(self)

 if btnp(⬅️) then
  self:_try_move(-1,0)
 end
 if btnp(➡️) then
  self:_try_move(1,0)
 end
 if btnp(⬆️) then
  self:_try_move(0,-1)
 end
 if btnp(⬇️) then
  self:_try_move(0,1)
 end
 if btnp(❎) then
  if (
   self.selected==nil or
   not self:try_root(
    self.selected
   )
  ) then
   sfx(13)
  end
 end
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
 o:_nxt_rooting()

 return o
end

function cplayer:_nxt_rooting()
 self.root_age=0.2+rnd(0.6)
end

function cplayer:update()
 player.update(self)

 local ns=#self.seeds
 if (ns==0) return

 self.switch_count-=1
 if self.switch_count<0 then
  self.selected_idx+=1
  self.switch_count=15
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
  [9]=-13,--blue/green
  [5]=-11,--dark grey (tree)
  [10]=-5,--med. green
  [6]=-15
 },1)

 stats=stats:new()
 levelmenu=levelmenu:new(stats)
 mainmenu=mainmenu:new()

 scene=mainmenu
end

game={}
function game:new(level,stats)
 local o=setmetatable({},self)
 self.__index=self

 o:load_level(level)
 o.stats=stats
 o.start=time()

 return o
end

function game:load_level(level)
 local ld=level_defs[
  level
 ].data
 self.level=level

 --todo: make members?
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
  end
  add(self.players,plyr)
  grid:add_observer(plyr)

  local t=tree:new(
   p[1],p[2],{player=plyr}
  )
  t.age=0.7
  add(trees,t)
 end

 if ld.goals then
  local areas={}
  for args in all(ld.goals) do
   add(areas,rectgoal(args))
  end
  self.goal=areagoal:new(
   areas,self.players
  )
 else
  self.goal=treegoal:new(
   grid,self.players,ld.target
  )
 end
 grid:add_observer(self.goal)

 for t in all(trees) do
  grid:add(t)
 end

 local params=ld.params or {}
 maxgrowrate=(
  params.maxgrowrate or
  default_maxgrowrate
 )
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

 local human=self.players[1]
 local winner=self.goal.winner

 local msg={}
 if winner!=nil then
  if winner==human then
   local time_taken=(
    time()-self.start
   )
   local tt=winner.total_trees
   if (time_taken<0) then
    --guard against wrapping
    time_taken=999
   end
   self.stats:mark_done(
    self.level,time_taken,tt
   )
   add(msg,"level complete!")
   add(msg,"")
   add(
    msg,"⧗"..time_str(
     time_taken
    )
   )
   add(msg,tt.." trees planted")
   sfx(4)
  else
   add(msg,"beaten by bots")
   sfx(8)
  end
 elseif (
  #human.seeds+#human.trees==0
 ) then
  add(msg,"game over")
  sfx(8)
 end

 if #msg>0 then
  self.anim=cowrap(
   "gameend",
   gameend_anim,self,msg
  )
 end
end

function game:draw()
 cls(1)

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

-- self.goal:draw_debug()

 camera()

 self.goal:draw()
 if self.msg!=nil then
  local y=63-3*#self.msg
  local c=7
  for txt in all(self.msg) do
   print(txt,63-#txt*2,y,c)
   y+=6
   c=4
  end
 end
end

function _draw()
 scene:draw()
end

function _update()
 scene:update()
end
__gfx__
00000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000676000000600000000000000000000000000000c0000c00000000000000000000000000000000000000000
00700700000000000000000000000000000660000067600000060000000000000000000000c00c0000c00c000000000000000000000000000000000060000000
000770000000000000000000000600000067650000676000000600000000000000000000000cc000000cc0000cc00cc000000000000660000600000000000060
0007700000000000000760000067500000666500677777600666660000000000000cc000000cc00000000000000cc00000c00c00006765000006670000000000
00700700000600000006500000050000000550000677760000666000000000000000000000000000000000000000000000000000006665000067650000066000
00000000000000000000000000000000000000000067600000060000000000000000000000000000000000000000000000000000000000000600006000000000
00000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000060000006
77777777777777777777777777777777777777777777777777777777711551175555555555555551555555515555555577777777777777777757757777777777
77777777777777777777777777777777777777777777777777777777155555515555555155555551555555515555555177777777777777777557755755555555
11001111001101001551115100000000666666661111111116666661555555555555555555555551555555515555555555555555555555555556655511111111
11111100110000111110551100000000666666666666666666666666555555555555555155555551555555515555555155555551555555555556655500000000
01111111001110005155100166666666666666666666666666666666155555515555555555555551555555515555555555555555555555555556655555555555
11101111011101101011155166666666666666666666666666666666011551101111111151151151111111115115115155555551555555555556655555555555
11111001100001001105511166666666666666666666666666666666000000000000000000000000000000000000000055555555555555555516615555555555
10011111000110115511115566666666666666666666666666666666100000010000000000000000000000000000000051515151555555555166661555555555
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000777777777777777701111110111551115555555573333337
00000000000000000000000000000000000000000000000000000000000000000000000000000000777777777777777711555511155555515555555533339933
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006666666615555551555555555555555533333339
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666ddd6615555551555555555555555539933399
00000000000000000000000000000000000000000000000000000000000000000000000000000000666666666666666611555511155555515555555593339999
0000000000000000000000000000000000000000000000000000000000000000000000000000000066666666d66666dd01111110011551105555555519999991
000000000000000000000000000000000000000000000000000000000000000000000000000000006666666666ddd66600000000000000000000000014141441
000000000000000000000000000000000000000000000000000000000000000000000000000000006dd666d66666666610000001100000010000000001441410
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000091011121212121011171212171011191
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000091110171212171110121212121110191
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000091011101110111011121212121011191
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000091110111011101110171212171110191
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000091313101110111011101110111011191
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000091414111011101110111011101110191
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000818181818181818181818181818181a1
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000818181818181818181818181818181a100
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
04554000000044400455400000004440045540000000444004554000000044400455400000004440045540000000444000000000000000000000000000000000
05005400004455540500540000445554450054000044555445005400004455544500540000445554750054000044555400000000000000000000000000000000
00000540445500050000054044550005500005404455000550000540445500055000054044550004500005404455000700000000000000000000000000000000
00000057750000000000005775000000000000577500000000000057750000000000005775000005000000577500000500000000000000000000000000000000
00000044540000000000004454000000000000445400000000000044540000004000004454000000700000445400000000000000000000000000000000000000
40004455054000004000445505400000400044550540000440004455054000044000445505400004400044550540000700000000000000000000000000000000
54445500005400405444550000540040544455000054004554445500005400455444550000540045544455000054004500000000000000000000000000000000
05750000000544500575000000054450057500000005445005750000000544500575000000054450057500000005445000000000000000000000000000000000
00540000000475000054400000047500005440000004750000544000000475000054400000047500005440000004750000000000000000000000000000000000
00050000000550000005500000455000000550000045500000055400044550000005540044455000000557007445500000000000000000000000000000000000
00000000000000000000000000500000000000000050000000000500055000000000050055500000000005005550000000000000000000000000000000000000
__label__
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggoooogggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggoooogggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggooeeoo22gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggooeeoo22gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggoooooo22ggggggggggooooggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggeeeegggggggggggggg
ggggggggggggggggggggggggggggoooooo22ggggggggggooooggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggeeeegggggggggggggg
gggggggggggggggggggggggggggggg2222ooggggooggooeeoo22gggggggggggggggggggggggggggggggggggggggggg4444eeggggeeggeeffee22gggggggggggg
gggggggggggggggggggggggggggggg2222ooggggooggooeeoo22gggggggggggggggggggggggggggggggggggggggggg4444eeggggeeggeeffee22gggggggggggg
ggggggggggggggggggggggggggoo44llllllggggll44oooooo22ggggggggggggggggggggggggggggggggggggggee44llllllggggll44eeeeee22gggggggggggg
ggggggggggggggggggggggggggoo44llllllggggll44oooooo22ggggggggggggggggggggggggggggggggggggggee44llllllggggll44eeeeee22gggggggggggg
gggggggggggggggggggggggg4444llggggggggggggllll2222gggggggggggggggggggggggggggggggggggggg4444llggggggggggggllll2222gggggggggggggg
gggggggggggggggggggggggg4444llggggggggggggllll2222gggggggggggggggggggggggggggggggggggggg4444llggggggggggggllll2222gggggggggggggg
gggggggggggggggggggggg44llll44gggggggggggggg444444gggggggggggggggggggggggggggggggggggg44llll44gggggggggggggg444444gggggggggggggg
gggggggggggggggggggggg44llll44gggggggggggggg444444gggggggggggggggggggggggggggggggggggg44llll44gggggggggggggg444444gggggggggggggg
ggggggggggggggggggggoollggggll44gggggggg4444llllll44ggggggggggggggggggggggggggggggeeeellggggll44gggggggg4444llllll44gggggggggggg
ggggggggggggggggggggoollggggll44gggggggg4444llllll44ggggggggggggggggggggggggggggggeeeellggggll44gggggggg4444llllll44gggggggggggg
ggggggggggggggggggggllggggggggll44gg4444llllggggggooggggggggggggggggggggggggggggeeffee22ggggggll44gg4444llllggggggeegggggggggggg
ggggggggggggggggggggllggggggggll44gg4444llllggggggooggggggggggggggggggggggggggggeeffee22ggggggll44gg4444llllggggggeegggggggggggg
gggggggggggggggggggggggggggggggglloooollggggggggooooggggggggggggggggggggggggggggeeeeee22gggggggglleeeellggggggggggllgggggggggggg
gggggggggggggggggggggggggggggggglloooollggggggggooooggggggggggggggggggggggggggggeeeeee22gggggggglleeeellggggggggggllgggggggggggg
ggggggggggggggggggggoogggggggggg4444ll44ggggggooeeoo22gggggggggggggggggggggggggggg2222gggggggggg4444ll44gggggggggggggggggggggggg
ggggggggggggggggggggoogggggggggg4444ll44ggggggooeeoo22gggggggggggggggggggggggggggg2222gggggggggg4444ll44gggggggggggggggggggggggg
gggggggggggggggggggg44gggggg4444llllllll44ggggoooooo22gggggggggggggggggggggggggggggg44gggggg4444llllllll44ggggggggeegggggggggggg
gggggggggggggggggggg44gggggg4444llllllll44ggggoooooo22gggggggggggggggggggggggggggggg44gggggg4444llllllll44ggggggggeegggggggggggg
ggggggggggggggggggggll444444llllgg44llggll44gggg2222ggggggggggggggggggggggggggggggggll444444llllgg44llgglleeeegg44llgggggggggggg
ggggggggggggggggggggll444444llllgg44llggll44gggg2222ggggggggggggggggggggggggggggggggll444444llllgg44llgglleeeegg44llgggggggggggg
gggggggggggggggggggggglloollgggggg44llggggll4444llgggggggggggggggggggggggggggggggggggglleellgggggg44llggeeffee22llgggggggggggggg
gggggggggggggggggggggglloollgggggg44llggggll4444llgggggggggggggggggggggggggggggggggggglleellgggggg44llggeeffee22llgggggggggggggg
ggggggggggggggggggggggggll4444gggg44llgggg44oollggggggggggggggggggggggggggggggggggggggggll4444gggg44llggeeeeee22gggggggggggggggg
ggggggggggggggggggggggggll4444gggg44llgggg44oollggggggggggggggggggggggggggggggggggggggggll4444gggg44llggeeeeee22gggggggggggggggg
ggggggggggggggggggggggggggllllooggggoo4444llllgggggggggggggggggggggggggggggggggggggggggggglllleeggggee44442222gggggggggggggggggg
ggggggggggggggggggggggggggllllooggggoo4444llllgggggggggggggggggggggggggggggggggggggggggggglllleeggggee44442222gggggggggggggggggg
ggggggggggggggggggggggggggggggllggggllllllggggggggggggggggggggggggggggggggggggggggggggggggggggllggggllllllgggggggggggggggggggggg
ggggggggggggggggggggggggggggggllggggllllllggggggggggggggggggggggggggggggggggggggggggggggggggggllggggllllllgggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggrrrrggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggddddgggggggggggggg
ggggggggggggggggggggggggrrrrggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggddddgggggggggggggg
ggggggggggggggggggggggrrbbrr33ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggddccdd22gggggggggggg
ggggggggggggggggggggggrrbbrr33ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggddccdd22gggggggggggg
ggggggggggggggggggggggrrrrrr334444rrggggrrgggggggggggggggggggggggggggggggggggggggggggggggggggg4444ddggggddggdddddd22gggggggggggg
ggggggggggggggggggggggrrrrrr334444rrggggrrgggggggggggggggggggggggggggggggggggggggggggggggggggg4444ddggggddggdddddd22gggggggggggg
gggggggggggggggggggggggg333344llllllggggll4444ggggrrrrggggggggggggggggggggggggggggggggggggdd44llllllggggll44442222gggggggggggggg
gggggggggggggggggggggggg333344llllllggggll4444ggggrrrrggggggggggggggggggggggggggggggggggggdd44llllllggggll44442222gggggggggggggg
gggggggggggggggggggggggg4444llggggggggggggllllrrrrbbrr33gggggggggggggggggggggggggggggggg4444llggggggggggggllllddgggggggggggggggg
gggggggggggggggggggggggg4444llggggggggggggllllrrrrbbrr33gggggggggggggggggggggggggggggggg4444llggggggggggggllllddgggggggggggggggg
gggggggggggggggggggggg44llll44gggggggggggggg4444rrrrrr33ggggggggggggggggggggggggggdddd44llll44gggggggggggggg444444gggggggggggggg
gggggggggggggggggggggg44llll44gggggggggggggg4444rrrrrr33ggggggggggggggggggggggggggdddd44llll44gggggggggggggg444444gggggggggggggg
ggggggggggggggggggggrrllggggll44gggggggg4444llllll3333ggggggggggggggggggggggggggddccdd22ggggll44gggggggg4444llllll44gggggggggggg
ggggggggggggggggggggrrllggggll44gggggggg4444llllll3333ggggggggggggggggggggggggggddccdd22ggggll44gggggggg4444llllll44gggggggggggg
ggggggggggggggggggggllggggggggll44gg4444llllggggggrrggggggggggggggggggggggggggggdddddd22ggggggll44gg4444llllggggggddgggggggggggg
ggggggggggggggggggggllggggggggll44gg4444llllggggggrrggggggggggggggggggggggggggggdddddd22ggggggll44gg4444llllggggggddgggggggggggg
ggggggggggggggggggggggggggggggggllrrrrllggggggggggllgggggggggggggggggggggggggggggg2222ggggggggggllddddllggggggddddllgggggggggggg
ggggggggggggggggggggggggggggggggllrrrrllggggggggggllgggggggggggggggggggggggggggggg2222ggggggggggllddddllggggggddddllgggggggggggg
ggggggggggggggggggggrrgggggggggg4444ll44ggggggggggggggggggggggggggggggggggggggggggggddgggggggggg4444ll44ggggddccdd22gggggggggggg
ggggggggggggggggggggrrgggggggggg4444ll44ggggggggggggggggggggggggggggggggggggggggggggddgggggggggg4444ll44ggggddccdd22gggggggggggg
gggggggggggggggggggg44gggggg4444llllllll44ggggggggrrgggggggggggggggggggggggggggggggg44gggggg4444llllllll44ggdddddd22gggggggggggg
gggggggggggggggggggg44gggggg4444llllllll44ggggggggrrgggggggggggggggggggggggggggggggg44gggggg4444llllllll44ggdddddd22gggggggggggg
ggggggggggggggggggggll444444llllrrrrllggll44gggg44llggggggggggggggggggggggggggggggggll444444llllgg44llggll44gg2222llgggggggggggg
ggggggggggggggggggggll444444llllrrrrllggll44gggg44llggggggggggggggggggggggggggggggggll444444llllgg44llggll44gg2222llgggggggggggg
ggggggggggggggggggggggllrrllggrrbbrr33ggggll4444llggggggggggggggggggggggggggggggggggggllddllgggggg44llggggll4444llgggggggggggggg
ggggggggggggggggggggggllrrllggrrbbrr33ggggll4444llggggggggggggggggggggggggggggggggggggllddllgggggg44llggggll4444llgggggggggggggg
ggggggggggggggggggggggggll4444rrrrrr33gggg44rrllggggggggggggggggggggggggggggggggggggggggll4444gggg44llgggg44ddllgggggggggggggggg
ggggggggggggggggggggggggll4444rrrrrr33gggg44rrllggggggggggggggggggggggggggggggggggggggggll4444gggg44llgggg44ddllgggggggggggggggg
ggggggggggggggggggggggggggllllrr3333rr4444llllggggggggggggggggggggggggggggggggggggggggggggllllddggggdd4444llllgggggggggggggggggg
ggggggggggggggggggggggggggllllrr3333rr4444llllggggggggggggggggggggggggggggggggggggggggggggllllddggggdd4444llllgggggggggggggggggg
ggggggggggggggggggggggggggggggllggggllllllggggggggggggggggggggggggggggggggggggggggggggggggggggllggggllllllgggggggggggggggggggggg
ggggggggggggggggggggggggggggggllggggllllllggggggggggggggggggggggggggggggggggggggggggggggggggggllggggllllllgggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg

__gff__
0000000000000000000000000000000000000104040404020202020208080202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040402020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1b18181818181818181818181818191b18181818181818181818181818191c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140000000000001414141414141414141414141414141414
1910111011101110111011101110191910111011101110111011101110191c101110111011101110111011101c1410111011101114111011101110141011101110111011101110111011141011101110111011101110111011101410101010101414141111111111140000000000001410111014101110141011101410111014
1911101110111011101110111011191911101110111011101110111011191c111011101110111011101110111c1411121212121014101212121211141110111011101110111011101110141110111011101110111011101110111410121212101d1d1d1112121211140000000000001411101114111011141110111411101114
1910111212121110111212121110191910111212121210121212121110191c10111212121c1c1c12121211101c141012121212111d111212121210141011101110111011101110111011141012121210111011101110121212101410121212101d1d1d1112121211140000000000001410111014101110141011101610111014
1911101212121011101212121011191911101212121219121212121011191c11101212121c1c1c12121210111c141112121212101d1012121212111411101110111011101110111011101411121212111018181a1011121212111410121212101d1d1d1112121211140000000000001413131314131313141313131413131314
1910111212121110111212121110191910111212121219121212121110191c10111212121c1c1c12121211101c1410121212121115111212121210141313131313131313131310111011141012121210111011101110121212101410101010101515151111111111140000000000001410111014101110141011101410111014
1911101110111011101110111011191911101212121219121212121011191c11101c1c1c1c1c1c1c1c1c10111c14111011101110141011101110111411101110111212121214111011101411101110111011101110111011101114131d1d1d13141414131d1d1d13140000000000001411101114111011141110111411101114
191011101110111011101110111019191011101818181b181818101110191c10111c1c1c1c1c1c1c1c1c11101c1413131d1d13131413131d1d1313141011101110121212121410111011141011101110111d1d1d11101110111014141d1d1d14141414141d1d1d14140000000000001410111014101110141011101410111014
1911101110111011101110111011191911101212121219121212121011191c11101c1c1c1c1c1c1c1c1c10111c1411101110111014101110111011141110111011121212121411101110141313131313131d1d1d13131313131314141d1d1d14141414141d1d1d14140000000000001413131314131313141313131413131314
1910111212121110111212121110191910111212121219121212121110191c10111212121c1c1c12121211101c1410121212121114111212121210141011101110121212121410111011141011101110111d1d1d1110111011101411111111111414141010101010140000000000001410111014101110141011101410111014
1911101212121011101212121011191911101212121219121212121011191c11101212121c1c1c12121210111c141112121212101d101212121211141110111013131313131411101110141110111011101110111011101110111411121212111d1d1d1012121210140000000000001411101114111011141110111411101114
1910111212121110111212121110191910111212121210121212121110191c10111212121c1c1c12121211101c141012121212111d111212121210141011101110111011101110111011141012121210111011101110121212101411121212111d1d1d1012121210140000000000001410111014101110141011101410111014
1911101110111011101110111011191911101110111011101110111011191c111011101110111011101110111c14111212121210151012121212111411101110111011101110111011101411121212111018181a1011121212111411121212111d1d1d1012121210140000000000001413131314131313141313131413131314
1910111011101110111011101110191910111011101110111011101110191c101110111011101110111011101c1410111011101114111011101110141011101110111011101110111011141012121210111011101110121212101411111111111515151010101010140000000000001410111014101110141011101410111014
18181818181818181818181818181a18181818181818181818181818181a1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1413131313131314131313131313141110111011101110111011101110141110111011101110111011101110111413131313131414141313131313140000000000001411101114111011141110111411101114
1414141414141414141414141414141414141414141414141414141414141414141414141414141414141414140000000000000000000000000000141313131313131313131313131313141011101110111011101110111011101400000000000000000000000000000000000000001410111014101110141011101410111014
1412121212121414141212121212141111121211111212111112121111141111111011111414111110111111140000000000000000000000000000000000000000000000000000000000141313131313131313131313131313131400000000000000000000000000000000000000001413131314131313141313131413131314
1412121212121414141212121212141111121211111212111112121111141111111011111414111110111111140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001410111014101110141011101410111014
1412121212121414141212121212141212111112121111121211111212141111111310101111101013111111140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001411101114111011141110111411101114
1412121212121d1d1d1212121212141212111112121111121211111212141010131410101111101014131010140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001410111014101110141011101410111014
1412121212121d1d1d1212121212141111121211111212111112121111141111101013131010131310101111140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001413131314131313141313131413131314
141313131d1d1515151d1d13131314111112121111121211111212111114111110101414101014141010111114000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b181818181818181818181818181819
141414141d1d1414141d1d141414141212111112121111121211111212141313111110101313101011111313140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019101110111011101110111011131319
141414141d1d1414141d1d141414141212111112121111121211111212141414111110101414101011111414140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019111011101110111011101110141419
1412121212121d1d1d1212121212141111121211111212111112121111141111101013131010131310101111140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019101117121217101110111011101119
1412121212121d1d1d1212121212141111121211111212111112121111141111101014141010141410101111140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019111012121212111011101110111019
1412121212121515151212121212141212111112121111121211111212141010131310101111101013131010140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019101112121212101117121217101119
1412121212121414141212121212141212111112121111121211111212141111111410101111101014121212140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019111017121217111012121212111019
1412121212121414141212121212141111121211111212111112121111141111111011111313111110121212140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019101110111011101112121212101119
1413131313131414141313131313141111121211111212111112121111141111111011111414111110121212140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019111011101110111017121217111019
0000000000000000000000000000141313131313131313131313131313141313131313131414131313131313140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019101117121217101110111011101119
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019111012121212111011101110111019
__sfx__
01020000256402564024630216301d620156200d6200a61006610056100361503600026051a6001960015600116000e6000860003600026050060000600006000060000600006000060000600006000060000600
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
