file riscboy_ppu.v
file riscboy_ppu_background.v
file riscboy_ppu_blender.v
file riscboy_ppu_busmaster.v
file riscboy_ppu_dispctrl.v
file riscboy_ppu_palette_ram.v
file riscboy_ppu_palette_mapper.v
file riscboy_ppu_pixel_gearbox.v
file riscboy_ppu_pixel_streamer.v
file riscboy_ppu_poker.v
file riscboy_ppu_raster_counter.v
file riscboy_ppu_sprite.v
file riscboy_ppu_sprite_agu.v
file regs/ppu_regs.v
include .

list $LIBFPGA/cdc/async_fifo.f
file $LIBFPGA/common/onehot_mux.v
file $LIBFPGA/common/onehot_priority.v
file $LIBFPGA/common/onehot_encoder.v
file $LIBFPGA/common/onehot_priority_dynamic.v
file $LIBFPGA/common/reset_sync.v
file $LIBFPGA/common/dffe_out.v
file $LIBFPGA/common/ddr_out.v
