#![no_std]
#![no_main]

use aya_ebpf::{helpers::{bpf_probe_read_buf, bpf_probe_read_kernel, bpf_probe_read_kernel_buf, bpf_probe_read_user_str_bytes}, macros::kprobe, maps::RingBuf, programs::ProbeContext};
use aya_log_ebpf::info;
pub mod task_st;

use crate::task_st::{task_struct, pt_regs};




#[kprobe]
pub fn hello_world(ctx: ProbeContext) -> u32 {
    match try_hello_world(ctx) {
        Ok(ret) => ret as _,
        Err(ret) => ret as _ ,
    }
}

fn try_hello_world(ctx: ProbeContext) -> Result<i32, i32> {
    let mut buf = [0u8; 16];
    let task : *const pt_regs = ctx.arg(0).ok_or(-1)?;
    let filename = unsafe {
        bpf_probe_read_kernel(&raw const (*task).di)
    }?;
    let nm = unsafe {bpf_probe_read_user_str_bytes(filename as *const u8, &mut buf)}?;
    info!(&ctx, "kprobe called");
    info!(&ctx, "filename bytes: {:x}", nm);
    Ok(0)
}

#[cfg(not(test))]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[unsafe(link_section = "license")]
#[unsafe(no_mangle)]
static LICENSE: [u8; 13] = *b"Dual MIT/GPL\0";


