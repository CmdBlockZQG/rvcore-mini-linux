#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2019 Western Digital Corporation or its affiliates.
#

# Compiler pre-processor flags
platform-cppflags-y =

# C Compiler and assembler flags.
platform-cflags-y =
platform-asflags-y =

# Linker flags: additional libraries and object files that the platform
# code needs can be added here
platform-ldflags-y =

#
# Command for platform specific "make run"
# Useful for development and debugging on plaftform simulator (such as QEMU)
#
# platform-runcmd = your_platform_run.sh

#
# Platform RISC-V XLEN, ABI, ISA and Code Model configuration.
# These are optional parameters but platforms can optionaly provide it.
# Some of these are guessed based on GCC compiler capabilities
#
PLATFORM_RISCV_XLEN = 32
PLATFORM_RISCV_ABI = ilp32
PLATFORM_RISCV_ISA = rv32ima_zicsr_zifencei_zicntr
PLATFORM_RISCV_CODE_MODEL = medany

# Space separated list of object file names to be compiled for the platform
platform-objs-y += platform.o

#
# If the platform support requires a builtin device tree file, the name of
# the device tree compiled file should be specified here. The device tree
# source file be in the form <dt file name>.dts
#
platform-objs-y += rvcore.o

# Optional parameter for path to external FDT
FW_FDT_PATH=/home/cmdblock/Develop/rvcore-mini-linux/build/opensbi/platform/rvcore/rvcore.dtb

#
# Dynamic firmware configuration.
# Optional parameters are commented out. Uncomment and define these parameters
# as needed.
#
FW_DYNAMIC=n

#
# Jump firmware configuration.
# Optional parameters are commented out. Uncomment and define these parameters
# as needed.
#
FW_JUMP=n
# This needs to be 4MB aligned for 32-bit support
# This needs to be 2MB aligned for 64-bit support
# ifeq ($(PLATFORM_RISCV_XLEN), 32)
# FW_JUMP_OFFSET=0x400000
# else
# FW_JUMP_OFFSET=0x200000
# endif
# FW_JUMP_FDT_OFFSET=0x2200000
#
# You can use fixed address for jump firmware as an alternative option.
# SBI will prefer "<X>_ADDR" if both "<X>_ADDR" and "<X>_OFFSET" are
# defined
# ifeq ($(PLATFORM_RISCV_XLEN), 32)
# FW_JUMP_ADDR=0x80400000
# else
# FW_JUMP_ADDR=0x80200000
# endif
# FW_JUMP_FDT_ADDR=0x82200000

#
# Firmware with payload configuration.
# Optional parameters are commented out. Uncomment and define these parameters
# as needed.
#
FW_PAYLOAD=y
# This needs to be 4MB aligned for 32-bit support
# This needs to be 2MB aligned for 64-bit support
# ifeq ($(PLATFORM_RISCV_XLEN), 32)
# FW_PAYLOAD_OFFSET=0x400000
# else
# FW_PAYLOAD_OFFSET=0x200000
# endif
FW_PAYLOAD_ALIGN=0x400000
FW_PAYLOAD_PATH=/home/cmdblock/Develop/rvcore-mini-linux/build/linux-6.10.9/arch/riscv/boot/Image
# FW_PAYLOAD_FDT_OFFSET=0x2200000
#
# You can use fixed address for payload firmware as an alternative option.
# SBI will prefer "FW_PAYLOAD_FDT_ADDR" if both "FW_PAYLOAD_FDT_OFFSET"
# and "FW_PAYLOAD_FDT_ADDR" are defined.
# FW_PAYLOAD_FDT_ADDR=0x82200000
