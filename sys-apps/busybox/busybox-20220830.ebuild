# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic

DESCRIPTION="Utilities for rescue and embedded systems"
HOMEPAGE="https://www.busybox.net/"

SNAPSHOT=526625bc83e63e6e5a3ec5296a1b868e72b3b01e
SRC_URI="https://git.busybox.net/busybox/snapshot/${PN}-${SNAPSHOT}.tar.bz2 -> ${P}.tar.bz2"
S=${WORKDIR}/${PN}-${SNAPSHOT}

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="alpha amd64 arm arm64 hppa ia64 loong m68k mips ppc ppc64 riscv s390 sparc x86 amd64-linux x86-linux"

RESTRICT="test strip"

BDEPEND="sys-libs/musl"

PATCHES=(
	"${FILESDIR}"/0001-adduser-default-to-sbin-nologin-as-shell-for-system-.patch
	"${FILESDIR}"/0001-nologin-Install-applet-to-sbin-instead-of-usr-sbin.patch
	"${FILESDIR}"/0001-properly-fix-wget-https-support.patch
	"${FILESDIR}"/0002-fsck-resolve-LABEL-.-UUID-.-spec-to-device.patch
	"${FILESDIR}"/0003-ash-exec-busybox.static.patch
	"${FILESDIR}"/0004-app-location-for-cpio-vi-and-lspci.patch
	"${FILESDIR}"/0005-udhcpc-set-default-discover-retries-to-5.patch
	"${FILESDIR}"/0006-ping-make-ping-work-without-root-privileges.patch
	"${FILESDIR}"/0007-fbsplash-support-console-switching.patch
	"${FILESDIR}"/0008-fbsplash-support-image-and-bar-alignment-and-positio.patch
	"${FILESDIR}"/0009-depmod-support-generating-kmod-binary-index-files.patch
	"${FILESDIR}"/0010-Add-flag-for-not-following-symlinks-when-recursing.patch
	"${FILESDIR}"/0012-udhcpc-Don-t-background-if-n-is-given.patch
)

src_prepare() {
	default
	cp "${FILESDIR}"/busybox-config "${S}"/.config || die
	make silentoldconfig
}

src_compile() {
	append-flags -ffat-lto-objects
	append-ldflags -static
	append-ldflags -Wl,-z,noexecstack

	emake CC=musl-gcc
}

src_install() {
	dobin busybox
	doman docs/busybox.1
}
