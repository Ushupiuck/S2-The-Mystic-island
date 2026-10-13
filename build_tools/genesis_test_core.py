"""Small optional libretro runner; supply a Genesis Plus GX shared library.

Uses the core's real 68000/VDP/Z80 and saves RGB screenshots. RAM writes are
explicit test-fixture positioning/state setup, never replacements for code.
"""
from pathlib import Path
import ctypes as C
import re
import numpy as np
from PIL import Image


class GameInfo(C.Structure):
    _fields_ = [('path', C.c_char_p), ('data', C.c_void_p),
                ('size', C.c_size_t), ('meta', C.c_char_p)]


class Variable(C.Structure):
    _fields_ = [('key', C.c_char_p), ('value', C.c_char_p)]


class Genesis:
    def __init__(self, core, rom, listing, output, pal=False):
        self.s = {name:int(value,16) for name,value in re.findall(
            r'\*?([A-Za-z_][\w.]*)\s*:\s*([0-9A-F]+)\s+[C-]',listing.read_text())}
        self.output = output
        output.mkdir(parents=True,exist_ok=True)
        self.frame, self.buttons, self.buttons2 = 0, set(), set()
        self.video, self.pixel_format = None, 0
        self.directory = str(output).encode()
        self.region = b'pal' if pal else b'ntsc-u'
        self.core = C.CDLL(str(core))
        ENV = C.CFUNCTYPE(C.c_bool,C.c_uint,C.c_void_p)
        VIDEO = C.CFUNCTYPE(None,C.c_void_p,C.c_uint,C.c_uint,C.c_size_t)
        AUDIO = C.CFUNCTYPE(None,C.c_int16,C.c_int16)
        BATCH = C.CFUNCTYPE(C.c_size_t,C.c_void_p,C.c_size_t)
        POLL = C.CFUNCTYPE(None)
        INPUT = C.CFUNCTYPE(C.c_int16,C.c_uint,C.c_uint,C.c_uint,C.c_uint)

        def environment(cmd,data):
            if cmd in (9,31,30):
                C.cast(data,C.POINTER(C.c_char_p))[0] = self.directory
                return True
            if cmd == 10:
                self.pixel_format = C.cast(data,C.POINTER(C.c_uint))[0]
                return True
            if cmd == 15:
                var = C.cast(data,C.POINTER(Variable)).contents
                var.value = self.region if var.key == b'genesis_plus_gx_region_detect' else None
                return var.value is not None
            if cmd == 17:
                C.cast(data,C.POINTER(C.c_bool))[0] = False
                return True
            if cmd == 3:
                C.cast(data,C.POINTER(C.c_bool))[0] = True
                return True
            return cmd in (6,8,11,16,18,32,35,37,42,44,52)

        def video(data,width,height,pitch):
            if not data:
                return
            pixels = np.frombuffer(C.string_at(data,pitch*height),'<u2').reshape(height,pitch//2)[:,:width]
            if self.pixel_format == 2:
                rgb = np.stack([(pixels>>11 &31)*255//31,
                                (pixels>>5 &63)*255//63,(pixels&31)*255//31],-1)
            else:
                rgb = np.stack([(pixels>>10 &31)*255//31,
                                (pixels>>5 &31)*255//31,(pixels&31)*255//31],-1)
            self.video = Image.fromarray(rgb.astype('uint8'))

        self.callbacks = [ENV(environment),VIDEO(video),AUDIO(lambda a,b:None),
                          BATCH(lambda data,frames:frames),POLL(lambda:None),
                          INPUT(lambda port,device,index,button:
                                int(button in (self.buttons if port==0 else self.buttons2)))]
        for name, callback in zip(('environment','video_refresh','audio_sample',
                                   'audio_sample_batch','input_poll','input_state'),self.callbacks):
            getattr(self.core,'retro_set_'+name)(callback)
        self.core.retro_init()
        self.core.retro_load_game.argtypes = [C.POINTER(GameInfo)]
        self.core.retro_load_game.restype = C.c_bool
        self.rom = C.create_string_buffer(rom.read_bytes())
        info = GameInfo(str(rom).encode(),C.cast(self.rom,C.c_void_p),len(self.rom)-1,None)
        assert self.core.retro_load_game(C.byref(info))
        self.ram = (C.c_uint8*65536).in_dll(self.core,'work_ram')
        self.vram = (C.c_uint8*65536).in_dll(self.core,'vram')
        self.core.m68k_get_reg.argtypes = [C.c_int]
        self.core.m68k_get_reg.restype = C.c_uint
        self.core.retro_serialize_size.restype = C.c_size_t
        self.core.retro_serialize.argtypes = [C.c_void_p,C.c_size_t]
        self.core.retro_unserialize.argtypes = [C.c_void_p,C.c_size_t]
        self.core.retro_serialize.restype = C.c_bool
        self.core.retro_unserialize.restype = C.c_bool

    def read(self, name, size=1):
        address = (self.s[name] if isinstance(name,str) else name)&65535
        return int.from_bytes(bytes(self.ram[(address+i)^1] for i in range(size)),'big')

    def write(self, name, value, size=1):
        address = (self.s[name] if isinstance(name,str) else name)&65535
        for i,b in enumerate((value&((1<<(size*8))-1)).to_bytes(size,'big')):
            self.ram[(address+i)^1] = b

    def get(self,actor,field,size=1):
        return self.read((self.s[actor] if isinstance(actor,str) else actor)+self.s[field],size)

    def put(self,actor,field,value,size=1):
        self.write((self.s[actor] if isinstance(actor,str) else actor)+self.s[field],value,size)

    def run(self, frames=1):
        for _ in range(frames):
            self.core.retro_run()
            self.frame += 1

    def save(self):
        state = C.create_string_buffer(self.core.retro_serialize_size())
        assert self.core.retro_serialize(state,len(state))
        return state

    def restore(self,state):
        assert self.core.retro_unserialize(state,len(state))
        self.buttons,self.buttons2 = set(),set()

    def close(self):
        self.core.retro_unload_game()
        self.core.retro_deinit()
