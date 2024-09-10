# RVCORE Mini Linux

为手搓的模拟器/RTL核实现，构建mini版本的Linux(with mmu)！

以尽量少的额外功能实现、尽量低的（与核本身无关的）硬件复杂度、尽量少的配置为宗旨！

- 核心本身方面
  - 只需要实现启动Linux的最低要求：RV32IMA

- 系统外设方面
  - CLINT肯定是要实现的，行为也需要和手册相符，但是只支持一个Hart就好了
  - 你甚至不需要实现PLIC
  - 你甚至不需要完整模拟真实串口的设备模型，只需要一个极简的实现
    - 当然，这样做就对shell输入支持很差。不过可以预制输入字符串，自动执行命令
  

## 核实现要求

- RV32IMA
  - 由于只有一个硬件线程，原子指令的实现非常简单
- 支持zifencei，zicsr，zicntr
  - 不需要实现zihpm
- 支持S模式和U模式，以及Sv32虚拟内存机制
- 无需支持指令集功能选择，misa只读，写入忽略即可
- 无需支持字节序切换，mstatus.MBE/SBE/UBE可均硬编码为0
- wip可实现为nop，U模式执行WFI可以立即触发非法指令异常，mstatus.TW可以忽略
- mconfigptr可硬编码为0，不实现相关功能
- 性能监视器，xenvcfg，mseccfg，PMP都可以不实现

## 外设实现

- CLINT需要完整实现，但只需要支持一个Hart
- 超简单的串口实现
  - 基地址偏移为0的写入直接输出即可，其他写操作全部忽略
  - 基地址偏移为0的读操作，返回下一个可读取的字符。若无字符可读取，返回0xff
  - 基地址偏移为5字节的读操作，返回`0x60 & x`，其中x表示是否有字符可供读取，有1无0
  - 其他读操作返回0即可
  - 由于驱动打开串口设备时会读取一次偏移为0的位置，预置输入字符串需要在最前面加一个占位的空格
  - 仓库根目录下`uart.cc`为一个参考实现

## 编译安装32位工具链

ubuntu软件包安装的工具链不带multilib，没有32位的软浮点等等实现，很难正常进行接下来的编译。

```
$ git clone https://github.com/riscv/riscv-gnu-toolchain
$ git submodule update --init --recursive
```

进入目录，配置并开始构建

```
$ cd riscv-gnu-toolchain
$ ./configure --prefix=/opt/riscv --with-arch=rv32ima --with-abi=ilp32 --enable-multilib
$ sudo make linux -j
```

只支持RISCV32-IMA

## 构建initramfs

Linux运行需要一个根文件系统。正常的根文件系统需要实现一个块设备，但是那个实现起来就麻烦了。Linux提供两种内存文件系统：initramfs和initrd。选用initramfs是因为initrd已经deprecated了，并且initramfs构建也更加简单。

一般的做法是在initramfs中放一个busybox，不过也可以自己构建根文件系统，往里面放自己编译的程序。我们的系统是带有MMU的完整Linux，可以运行elf格式的可执行文件。

### 编译BusyBox

直接去busybox.net下载源码并解压，这里的版本是1.36.1

```
$ cd busybox-1.36.1
$ make CROSS_COMPILE=riscv32-unknown-linux-gnu- defconfig
$ make CROSS_COMPILE=riscv32-unknown-linux-gnu- menuconfig
```

进入menuconfig界面，选中 Settings -> Build static binary (no shared libs)

```
$ make CROSS_COMPILE=riscv32-unknown-linux-gnu- -j
$ make CROSS_COMPILE=riscv32-unknown-linux-gnu- install
```

编译产物应该就在`_install`目录下了

> TODO: 还是含有C指令，疑似是libc的原因

### 编译自己的init程序

> TODO

### 镜像文件构建

initramfs是和内核打包在一起的。内核编译时可以接受两种initramfs输入：镜像cpio镜像文件，和描述文本文件。

#### CPIO镜像

```
$ mkdir initramfs
$ cd initramfs
$ find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs.cpio.gz
```

#### 描述文本文件

```
dir /dev 755 0 0

nod /dev/console 644 0 0 c 5 1
nod /dev/null 644 0 0 c 1 3

file /init /home/cmdblock/Develop/initramfs-new/hello 755 0 0
```

文件列表也可以用find命令生成

## 构建Linux内核

直接去kernel.org下载源码并解压，这里的版本是6.10.9

Linux的编译选项基于默认配置调整而来，而非最小配置。这样做会让编译/运行跑的慢一些，但是配置起来比较简单，对于核的实现测试也会更加充分（这点是我猜的，没什么依据）。

```
$ make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- defconfig
$ make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- menuconfig
```

进入menuconfig界面，调整以下设置

- 进入 Platform type
  - 启用 Allow configurations that result in non-portable kernels
  - Base ISA 改为 RV32I
  - 关闭 VECTOR extension support
  - 关闭 Zbb extension support for bit manipulation instructions
  - 关闭 Zicbom extension support for non-coherent DMA operation
  - 关闭 Zicboz extension support for faster zeroing of memory
  - 关闭 FPU support
  - Unaligned Accesses Support 根据实际情况选择
    - OpenSBI能够探测硬件对于非对齐访存的支持情况，不支持时会使用软件进行模拟
    - Linux内核也能够探测。但是OpenSBI对非对齐访存的软件支持，对于Linux内核来说是透明的
    - 也就是说Linux会认为机器支持非对齐的访存，但实际上这是OpenSBI模拟的
    - 默认选项会对非对齐访存进行速度测试，机器不支持非对齐访存的情况下这个过程非常缓慢
    - 所以建议选择 Assume the system supports slow unaligned memory access
    - 如果你的硬件支持快速的非对齐访问，可以选择自动探测，或者假设快速非对齐访存
- 进入 Boot options
  - 关闭 UEFI runtime support
    - 这需要对压缩指令的支持
- 重新进入 Platform type
  - 关闭 Emit compressed instructions when building Linux
    - 内核编译不产生压缩指令
- 进入 Kernel features
  - 打开 SBI v0.1 support
- 进入 Device Drivers - Character devices
  - 打开 RISC-V SBI console support
  - 进入 Serial drivers
    - 打开 Early console using RISC-V SBI
- 进入 General setup
  - 将 Initramfs source file(s) 改为镜像文件/描述文件

```
$ make ARCH=riscv CROSS_COMPILE=riscv32-unknown-linux-gnu- -j
```

编译得到`arch/riscv/boot/Image`内核镜像文件

## 构建OpenSBI

```
$ git clone https://github.com/riscv-software-src/opensbi.git
$ cd opensbi
$ git checkout release-1.5.x
```

笔者实验时的commit hash为`43cace6c3671e5172d0df0a8963e552bb04b7b20`

### 创建 Platform

进入`platform`目录，将template目录复制一份，重命名为你喜欢的名字，并进入该目录。

- 创建设备树文件`xxx.dts`
  
  - 可参考`rvcore/rvcore.dts`
  - 需要注意的是内核启动参数，`console=hvc0 earlycon=sbi`，这样做允许我们使用简陋的串口仿真模型运行真实的linux
    - 因为所有的输入输出都通过OpenSBI，whose串口驱动十分简单
  - 然后使用`dtc xxx.dts -o xxx.dtb`编译得到设备树blob(`.dtb`)文件
  
- 编辑`platform.c`

  - 编辑开头的宏定义
    - `PLATFORM_HART_COUNT`改为1，表示一个硬件线程
    - `PLATFORM_CLINT_ADDR`改为CLINT的地址
    - `PLATFORM_ACLINT_MTIMER_FREQ`可根据你的实现确定
    - `PLATFORM_UART_ADDR`改为串口设备地址
  - 将`plic`结构体变量的定义注释掉
  - 编辑`mtimer`结构体成员`has_64bit_mmio`为`false`
  - 将`platform_irqchip_init`函数注释掉
  - 编辑`platform_ops`结构体成员`irqchip_init`为`NULL`
  - 编辑`platform`结构体成员`name`为你喜欢的名字

- 编辑`objects.mk`

  - 编辑 Platform RISC-V XLEN, ABI, ISA and Code Model configuration

    - ```
      PLATFORM_RISCV_XLEN = 32
      PLATFORM_RISCV_ABI = ilp32
      PLATFORM_RISCV_ISA = rv32imac_zicsr_zifencei_zicntr
      PLATFORM_RISCV_CODE_MODEL = medany
      ```

  - 取消`# platform-objs-y += <dt file name>.o`注释，根据设备树文件名修改值，如`rvcore.o`

  - 取消`FW_FDT_PATH`注释，值改为设备树blob(`.dtb`)文件**绝对路径**

  - `FW_DYNAMIC`，`FW_JUMP`值改为`n`

  - `FW_PAYLOAD`值改为`y`

  - 将对`FW_PAYLOAD_OFFSET`赋值的ifeq语句直接全部注释掉

  - 取消`FW_PAYLOAD_ALIGN`注释，值改为`0x400000`

  - 取消`FW_PAYLOAD_PATH`注释，值改为Linux内核镜像文件**绝对路径**

仓库根目录下`rvcore`目录中为一个platform示例。

### 编译生成镜像

```
$ make CROSS_COMPILE=riscv32-unknown-linux-gnu- FW_TEXT_START=0x80000000 PLATFORM=rvcore
```

其中`FW_TEXT_START`为OpenSBI执行开始时的PC值。OpenSBI执行前，需要将整个镜像复制到该值开始的内存区域，并跳转到该地址。

`PLATFORM`即平台名，是你喜欢的名字。

镜像位于`platform/<你喜欢的名字>/firmware/fw_payload.bin`，打包了包括OpenSBI，Linux内核，initramfs在内的全部内容，可以直接在模拟器/RTL仿真中运行！（当然你或许需要一个bootloader）

修改前面步骤的文件内容后可能需要清理构建产物后重新编译：`make clean`，或者更加彻底地，`make distclean`
