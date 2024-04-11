// See LICENSE.SiFive for license details.

package freechips.rocketchip.system

import chisel3._
import freechips.rocketchip.config.Parameters
import freechips.rocketchip.devices.debug.Debug
import freechips.rocketchip.diplomacy.LazyModule
import freechips.rocketchip.util.AsyncResetReg
import freechips.rocketchip.devices.debug.DebugModuleKey
import chisel3.util.Fill
import freechips.rocketchip.devices.tilelink.PLICKey


class TestHarness()(implicit p: Parameters) extends Module {
  val io = IO(new Bundle {
    val success = Output(Bool())
  })

  val ldut = LazyModule(new ExampleRocketSystem)
  val dut = Module(ldut.module)

  // Allow the debug ndreset to reset the dut, but not until the initial reset has completed
  dut.reset := (reset.asBool | dut.debug.map { debug => AsyncResetReg(debug.ndreset) }.getOrElse(false.B)).asBool

  dut.dontTouchPorts()
  dut.tieOffInterrupts()
  SimAXIMem.connectMem(ldut)
  SimAXIMem.connectMMIO(ldut)
  ldut.l2_frontend_bus_axi4.foreach(_.tieoff)
  Debug.connectDebug(dut.debug, dut.resetctrl, dut.psd, clock, reset.asBool, io.success)
}




class SimpleHarness()(implicit p: Parameters) extends Module {
  val io = IO(new Bundle {
    val success = Output(Bool())
  })

  val ldut = LazyModule(new SimpleRocketSystem)
  val dut = Module(ldut.module)

  // Allow the debug ndreset to reset the dut, but not until the initial reset has completed
  dut.reset := reset.asBool()

  SimTLMem.connectMem(ldut)
  SimTLMem.connectMMIO(ldut)

  dut.dontTouchPorts()
  dut.tieOffInterrupts()
  SimAXIMem.connectMem(ldut)
  SimAXIMem.connectMMIO(ldut)

  // no interrupts coming from the outside
  dut.meip.map { case v =>
    v.foreach( _ := false.B )
  }

  ldut.l2_frontend_bus_axi4.foreach(_.tieoff)
  if (p(DebugModuleKey).nonEmpty) {
    Debug.connectDebug(dut.debug, dut.resetctrl, dut.psd, clock, reset.asBool, io.success)
  } else {
    io.success := true.B
  }
}
