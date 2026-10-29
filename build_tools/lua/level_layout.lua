-- Mode 1 layout validation runs on the host. The 68000 trusts these lookups.
local layouts = {}
local function read(path)
 local f=assert(io.open(path,"rb"),"Missing layout "..path)
 local data=f:read("*a");f:close();return data
end
local function decode(data)
 local p,desc,left,out=1,0,0,{}
 local function byte() local v=assert(data:byte(p),"Truncated Kosinski+ layout");p=p+1;return v end
 local function bit()
  if left==0 then desc=byte();left=8 end
  local v=desc>>7;desc=(desc<<1)&255;left=left-1;return v
 end
 while true do
  if bit()==1 then out[#out+1]=byte()
  else
   local offset,count
   if bit()==1 then
    local hi,lo=byte(),byte();offset=((hi&0xF8)<<5|lo)-8192;count=10-(hi&7)
    if hi&7==0 then count=byte();if count==0 then return out end;count=count+9 end
   else offset=byte()-256;count=2+bit()*2+bit() end
   for _=1,count do out[#out+1]=assert(out[#out+offset+1],"Invalid layout backreference") end
  end
 end
end
function layouts.validate()
 local seen,count={},0
 for _,source in ipairs({"md-main.asm","_inc/LevelLayouts_Timezones.asm"}) do
  for path in read(source):gmatch('binclude%s+"(level/layout/[^"]+%.kosp)"') do
   if not seen[path] then
    seen[path]=true;count=count+1
    local d=decode(read(path))
    local function word(o) return assert(d[o+1],path..": short layout")*256+assert(d[o+2]) end
    assert(word(0)==0x504C and word(2)==2,path..": expected PL version 2")
    assert(#d<=0x8000,path..": exceeds CD layout RAM")
    local cursor=1164
    for n=0,1 do
     local w,h=word(4+n*4),word(6+n*4)
     assert(w>=1 and w<=256 and h>=1 and h<=32,path..": invalid plane dimensions")
     local base=12+n*576;local start=cursor
     for _=1,h do
      for _=1,w do assert(word(cursor)<1024,path..": chunk bank overflow");cursor=cursor+2 end
      if n==0 then assert(word(cursor)==0,path..": foreground margin must be empty");cursor=cursor+2 end
     end
     local blank=cursor
     if n==0 then
      for _=1,w+1 do assert(word(cursor)==0,path..": empty border row changed");cursor=cursor+2 end
     end
     for y=0,31 do
      local row=n==1 and start+(y%h)*w*2 or (y<h and start+y*(w+1)*2 or blank)
      assert(word(base+y*2)==row-base,path..": stale row lookup")
     end
     for x=0,255 do
      local col=n==1 and x%w or math.min(x,w)
      assert(word(base+64+x*2)==col*2,path..": stale column lookup")
     end
    end
    assert(cursor==#d,path..": cell data length does not match plane dimensions")
   end
  end
 end
 print(string.format("Validated %d independent-plane layouts.",count))
end
return layouts
