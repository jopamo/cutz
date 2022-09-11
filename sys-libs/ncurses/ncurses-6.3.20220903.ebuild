# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_P="${PN}-$(ver_rs 2 -)"

inherit multilib-minimal

DESCRIPTION="console display library"
HOMEPAGE="http://invisible-island.net/ncurses/ https://www.gnu.org/software/ncurses/"
SRC_URI="https://invisible-mirror.net/archives/ncurses/current/${MY_P}.tgz"
S="${WORKDIR}/${MY_P}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="amd64 arm64"

IUSE="static-libs"

multilib_src_configure() {
	local myconf=(
		--disable-termcap
		--with-terminfo-dirs="${EPREFIX}"/usr/share/terminfo
		--with-pkg-config-libdir="${EPREFIX}/usr/$(get_libdir)/pkgconfig"
		--disable-stripping
		--disable-termcap
		--enable-colorfgbg
		--enable-echo
		--enable-ext-colors
		--enable-overwrite
		--enable-pc-files
		--enable-widec
		--with-pthread
		--with-shared
		--with-symlinks
		--with-termlib
		--without-debug
		--without-manpages
		--without-normal
	)
	ECONF_SOURCE=${S} econf "${myconf[@]}"
}

multilib_src_install() {
	default

	local i

	for i in ncurses form panel menu tinfo ; do
    	echo "INPUT(-l${i}tw)" > "${ED}"/usr/$(get_libdir)/lib${i}.so
    	echo "INPUT(-l${i}tw)" > "${ED}"/usr/$(get_libdir)/lib${i}w.so
    	dosym -r /usr/$(get_libdir)/pkgconfig/${i}tw.pc /usr/$(get_libdir)/pkgconfig/${i}.pc
    	dosym -r /usr/$(get_libdir)/pkgconfig/${i}tw.pc /usr/$(get_libdir)/pkgconfig/${i}w.pc
    	dosym -r /usr/$(get_libdir)/libtinfotw.so.$(ver_cut 1-2) /usr/$(get_libdir)/libtinfo.so.$(ver_cut 1)
    done

	echo "INPUT(-lncursestw)" > "${ED}"/usr/$(get_libdir)/libcurses.so

	use static-libs || find "${ED}"/usr/ -name '*.a' -delete
	use static-libs || find "${ED}" -name '*.la' -delete
}
