set out $::env(OUT)
set room $::env(ROOM)
proc dump {name} {
    global out
    foreach {what n sz} {VRAM vram 0x4000 memory ram 0x10000} {
        set f [open [file join $out ${name}_$n.bin] wb]; puts -nonewline $f [debug read_block $what 0 $sz]; close $f
    }
    set f [open [file join $out ${name}_regs.bin] wb]; puts -nonewline $f [debug read_block "VDP regs" 0 8]; close $f
}
set throttle off
debug set_bp 0x4237 {} { debug write memory 0xE101 $::room }
after time 8 { keymatrixdown 8 0x01 }
after time 8.2 { keymatrixup 8 0x01 }
after time 13 { keymatrixdown 8 0x01 }
after time 13.2 { keymatrixup 8 0x01 }
after time 16 "dump r[format %02d $room]"
after time 17 { exit }
