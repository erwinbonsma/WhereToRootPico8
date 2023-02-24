pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
-- where to root? v0.1.1
-- (c) 2023  eriban

frate=30
seed_r=2.5
tree_r=3
tree_h=5
branch_l=8
yscale=0.75
seeddrop_h=6

cellsz=8

families={
 {x=39,y=39,p={
  --red
  [6]=8,[5]=2,[7]=14
 }},
 {x=88,y=55,p={
  --pink
  [6]=14,[5]=2,[7]=15
 }},
 {x=39,y=87,p={
  --green
  [6]=10,[5]=3,[7]=11
 }},
 {x=88,y=103,p={
  --blue
  [6]=13,[5]=2,[7]=12
 }}
}

--sprite flags
flag_goal=0
flag_wall=1
flag_water=2

function vlen(dx,dy)
 return sqrt(dx*dx+dy*dy)
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

--class inheritance
function extend(clz,baseclz)
 for k,v in pairs(baseclz) do
  clz[k]=v
 end
end

cellgrid={}
function cellgrid:new(o)
 local o=setmetatable(o or {},self)
 self.__index=self

 o.w=o.w or 128
 o.h=o.h or 144
 --extra empty col to facilitate
 --left and right neighbour
 --checks at edge of grid
 o.ncols=ceil(o.w/cellsz)+1
 o.nrows=ceil(o.h/cellsz)
 o.cells={}
 for i=1,o.ncols*o.nrows do
  add(o.cells,{})
 end

 o.sorted_head={}
 for i=1,cellsz do
  add(o.sorted_head,0)
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

function cellgrid:_invalid_idx(
 ci
)
 return ci<1 or ci>#self.cells
end

function cellgrid:_invalid_pos(
 x,y
)
 return (
  x<0 or x>self.w-1 or
  y<0 or y>self.h-1
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

function cellgrid:_iswall(mx,my)
 local si=mget(
  self.mx+mx,self.my+my
 )
 return fget(si,flag_wall)
end

function cellgrid:_cellhit(
 ci,x,y,r,objx
)
 if self:_invalid_idx(ci) then
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

function cellgrid:_visit_hits(
 ci,x,y,r,visitor
)
 if self:_invalid_idx(ci) then
  return
 end

 for obj in all(self.cells[ci]) do
  local d=vlen(x-obj.x,y-obj.y)
  if d<obj.r+r then
   visitor(obj)
  end
 end
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
   ) and self:_iswall(
    mx+dx,my+dy
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

 local mx=self.mx+flr(x/cellsz)
 local my=self.my+flr(y/cellsz)

 for dx=-1,1 do
  for dy=-1,1 do
   if (
    dx!=0 or dy!=0
   ) and self:_maphit(
    x,y,dx,dy,r
   ) and self:_iswall(
    mx+dx,my+dy
   ) then
    return false
   end
  end
 end

 return true
end

function cellgrid:fits(x,y,r,objx)
 if self:_invalid_pos(x,y) then
  return false
 end

 if not self:_fits_map(x,y,r) then
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

function cellgrid:visit_hits(
 x,y,r,visitor
)
 if self:_invalid_pos(x,y) then
  return
 end

 local ci=self:_cellidx(x,y)

 for dx=-1,1 do
  for dy=-1,1 do
   self:_visit_hits(
    ci+dx+dy*self.ncols,
    x,y,r,visitor
   )
  end
 end
end

function cellgrid:draw_row(row)
 local sh=self.sorted_head
 for i=1,cellsz do
  sh[i]=0
 end

 --add to rows
 local ci=self:_cellidx(
  0,row*cellsz
 )
 for i=0,self.ncols-2 do
  for unit in all(
   self.cells[ci+i]
  ) do
   local idx=1+flr(
    unit.y%cellsz
   )
   unit._nxt=sh[idx]
   sh[idx]=unit
  end
 end

 --draw each row
 for i=1,cellsz do
  local unit=sh[i]
  while unit!=0 do
   unit:draw()
   unit=unit._nxt
  end
 end
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

function seeddrop_anim(args)
 local s=args[1]
 local kills=args[2]

 s.vh=0
 while s.h>0 do
  s.vh-=0.04
  s.h+=s.vh
  yield()

  if s.h<4 and kills!=nil then
   for kill in all(kills) do
    if (
     getmetatable(kill)==seed
    ) then
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

 s.h=0
 s.vh=nil
end

function seedsquash_anim(args)
 local seed=args[1]

 seed.si=8
 wait(4)

 while seed.si<10 do
  seed.si+=1
  wait(4)
 end

 seed.destroy=true
end

function seedsplat_anim(args)
 local seed=args[1]

 seed.vh=0
 while seed.h>2 do
  seed.vh-=0.04
  seed.h+=seed.vh
  yield()
 end

 seed.h=2
 seed.vh=nil

 seedsquash_anim({seed})
end

function seedroot_anim(args)
 local seed=args[1]
 local tree=args[2]
 seed.vh=0.5
 while seed.h>0 or seed.vh>0 do
  seed.vh-=0.04
  seed.h+=seed.vh
  yield()
 end
 yield()

 while seed.si<7 do
  seed.si+=1
  wait(10)
 end

 if seed:_tree_fits(tree) then
  grid:add(tree)
  add(units,tree)
 end

 seed.destroy=true
end

seed={}
function seed:new(dx,dy,o)
 local o=setmetatable(o or {},self)
 self.__index=self

 o.dx=dx
 o.dy=dy
 o.age=0
 o.growrate=(
  0.02+rnd(0.02)
 )/frate
 o.speed=o.speed or 0.1
 o.moving=true
 o.anim=nil
 o.si=o.si or 4

 return o
end

--check if tree fits. it may
--hit seeds, but not another
--tree
function seed:_tree_fits(t)
 local fits=true
 local visitor=function(obj)
  if getmetatable(obj)==tree then
   fits=false
  end
 end

 grid:visit_hits(
  t.x,t.y,t.r,visitor
 )

 return fits
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
  --try to root
  local t=tree:new(
   self.x,self.y,{
    family=self.family
   }
  )

  self.anim=cowrap(
   "root",seedroot_anim,self,t
  )

  --anim destroys seed
  return
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
 pal(self.family.p)
 spr(
  self.si,
  self.x-3,
  flr(self.y*yscale)-self.h-5
 )
 pal(0)
end

tree={}
function tree:new(x,y,o)
 local o=setmetatable(o or {},self)
 self.__index=self

 o.x=x
 o.y=y
 o.r=o.r or tree_r
 o.growrate=0.25/frate
 o.maxseeds=o.maxseeds or 3

 o.age=0
 o.seeds=nil

 return o
end

function tree:_blossom()
 self.seeds={}
 local angles=create_angles(
  self.maxseeds,0.15
 )

 for a in all(angles) do
  local s=seed:new(
   sin(a),cos(a),{
    family=self.family
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
 self.seed_si=1
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
  if (
   getmetatable(obj)==seed
  ) then
   add(kills,obj)
  else
   assert(
    getmetatable(obj)==tree
   )
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
 for seed in all(self.seeds) do
  hgrid:del(seed)

  local kills={}
  if self:_can_drop(
   seed,kills
  ) then
   seed.anim=cowrap(
    "seeddrop",seeddrop_anim,
    seed,kills
   )
  else
   seed.anim=cowrap(
    "seedsplat",seedsplat_anim,
    seed
   )
  end

  grid:add(seed)
  add(units,seed)
 end
end

function tree:update()
 if self.destroy then
  return true
 end

 self.age+=self.growrate

 if (self.age<0.7) return

 if self.seeds==nil then
  self:_blossom()
  return
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

 self:_dropseeds()
 return true
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
 line(x,y,x,y-h,4)
 line(x+1,y,x+1,y-h,5)
 line(
  x,y-h,x+1,y-h,
  self.family.p[6]
 )
end

function tree:draw_crown()
 if (self.age<=0.3) return

 local si=min(
  ceil((self.age-0.3)*40),17
 )
 pal(7,self.family.p[6])
 if si<5 then
  spr(
   tree_sprites[si],
   self.x-3,
   self.y*yscale-8
  )
 else
  spr(
   tree_sprites[si],
   self.x-7,
   self.y*yscale-11,
   2,2
  )
 end
 pal(0)
end

function _init()
 local lowrez=false

 grid=cellgrid:new(
  {mx=0,my=0}
 )
 hgrid=cellgrid:new()
 units={}
 for f in all(families) do
  local x=f.x
  local y=f.y
  if lowrez then
   x=(x-60)/2+60
   y=(y-60)/2+64
  end

  t=tree:new(x,y,{
   family=f
  })
  add(units,t)
  grid:add(t)
 end

 pal({
  [1]=-16,--dark brown (bg)
  [8]=-8, --dark red
  [9]=-13,--blue/green
  [5]=-11,--dark grey (tree)
  [10]=-5,--med. green
  [6]=-15
 },1)

 if lowrez then
  poke(0x5f2c,3)
  camera(-8+32,-16+32)
 else
  camera(0,-16)
 end
end

function _update()
 for i=#units,1,-1 do
  local destroy=units[i]:update()
  if destroy then
   grid:del(units[i])
   units[i]=units[#units]
   deli(units,#units)
  end
 end
end

function _draw()
 cls(1)

 --draw map and units on ground
 for row=0,17 do
  palt(7,true)
  palt(0,false)
  map(0,row,0,row*6-2,16,1)
  pal(0)

  grid:draw_row(row)
 end

 --draw tree tops
 for unit in all(units) do
  if getmetatable(unit)==tree then
   unit:draw_crown()
  end
 end

 --draw seeds on top of trees
 for row=0,17 do
  hgrid:draw_row(row)
 end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000660000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000
00077000000000000000000000060000006765000006600000000000000000000006600006000000000000600000000000000000000000000000000000000000
00077000000000000006500000675000006665000067650000066000000000000067650000066700000000000000000000000000000000000000000000000000
00700700000600000005500000050000000550000066650000676500000660000066650000676500000660000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000006000060000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000600000060000000000000000000000000000000000000000
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
77777777777777777777777777777777777777770000000000000000000000007115511755555555555555515555555155555555000000000000000000000000
77777777777777777777777777777777777777770000000000000000000000001555555155555551555555515555555155555551000000000000000000000000
11001111001101001551115100000000666666660000000000000000000000005555555555555555555555515555555155555555000000000000000000000000
11111100110000111110551100000000666666660000000000000000000000005555555555555551555555515555555155555551000000000000000000000000
01111111001110005155100166666666666666660000000000000000000000001555555155555555555555515555555155555555000000000000000000000000
11101111011101101011155166666666666666660000000000000000000000000115511011111111515151511111111151515151000000000000000000000000
11111001100001001105511166666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10011111000110115511115566666666666666660000000000000000000000001000000100000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000104040000000202020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040402020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4c49494949494949494949494949494a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a40414041404140414041404143434a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a41404140414041404140414044444a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a40414842424840414041404140414a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a41404242424241404140414041404a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a40414242424240414842424840414a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a41404842424841404242424241404a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a40414041404140414242424240414a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a41404140414041404842424841404a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a40414842424840404041404140414a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a41404242424241414140414041404a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a40414242424240414842424840414a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a41404842424841404242424241404a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a40414041404140414242424240414a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a41404140414041404842424841404a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a43434041404140414041404140414a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a44444140414041404140414041404a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4949494949494949494949494949494b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
