# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{8..11} )

inherit autotools libtool bash-completion-r1 python-r1

DESCRIPTION="library and tools for managing linux kernel modules"
HOMEPAGE="https://git.kernel.org/?p=utils/kernel/kmod/kmod.git"

SNAPSHOT=b4d281f962be74adfbae9d7bead6a7352033342c
SRC_URI="https://git.kernel.org/pub/scm/utils/kernel/kmod/kmod.git/snapshot/kmod-${SNAPSHOT}.tar.gz"
S=${WORKDIR}/${PN}-${SNAPSHOT}

LICENSE="LGPL-2"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 ~hppa ~ia64 ~loong ~m68k ~mips ~ppc ~ppc64 ~riscv ~s390 sparc x86"

IUSE="debug doc +lzma pkcs7 python static-libs +tools +zlib +zstd"

# Upstream does not support running the test suite with custom configure flags.
# I was also told that the test suite is intended for kmod developers.
# So we have to restrict it.
# See bug #408915.
RESTRICT="test"

# - >=zlib-1.2.6 required because of bug #427130
# - Block systemd below 217 for -static-nodes-indicate-that-creation-of-static-nodes-.patch
# - >=zstd-1.5.2-r1 required for bug #771078
RDEPEND="!sys-apps/module-init-tools
	!sys-apps/modutils
	!<sys-apps/openrc-0.13.8
	!<sys-apps/systemd-216-r3
	lzma? ( >=app-arch/xz-utils-5.0.4-r1 )
	python? ( ${PYTHON_DEPS} )
	pkcs7? ( >=dev-libs/openssl-1.1.0:= )
	zlib? ( >=sys-libs/zlib-1.2.6 )
	zstd? ( >=app-arch/zstd-1.5.2-r1:= )"
DEPEND="${RDEPEND}"
BDEPEND="
	doc? (
		dev-util/gtk-doc
		dev-util/gtk-doc-am
	)
	lzma? ( virtual/pkgconfig )
	python? (
		dev-python/cython[${PYTHON_USEDEP}]
		virtual/pkgconfig
	)
	zlib? ( virtual/pkgconfig )
"
if [[ ${PV} == 9999* ]]; then
	BDEPEND="${BDEPEND}
		dev-libs/libxslt"
fi

REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} )"

src_prepare() {
	default

	if [[ ! -e configure ]] ; then
		touch libkmod/docs/gtk-doc.make
		eautoreconf
	else
		elibtoolize
	fi

	# Restore possibility of running --enable-static, bug #472608
	sed -i \
		-e '/--enable-static is not supported by kmod/s:as_fn_error:echo:' \
		configure || die
}

src_configure() {
	local myeconfargs=(
		--bindir="${EPREFIX}/usr/sbin"
		--enable-shared
		--with-bashcompletiondir="$(get_bashcompdir)"
		--with-rootlibdir="${EPREFIX}/usr/$(get_libdir)"
		$(use_enable debug)
		$(usex doc '--enable-gtk-doc' '')
		$(use_enable static-libs static)
		$(use_enable tools)
		$(use_with lzma xz)
		$(use_with pkcs7 openssl)
		$(use_with zlib)
		$(use_with zstd)
	)

	local ECONF_SOURCE="${S}"

	kmod_configure() {
		mkdir -p "${BUILD_DIR}" || die
		run_in_build_dir econf "${myeconfargs[@]}" "$@"
	}

	BUILD_DIR="${WORKDIR}/build"
	kmod_configure --disable-python

	if use python; then
		python_foreach_impl kmod_configure --enable-python
	fi
}

src_compile() {
	emake -C "${BUILD_DIR}"

	if use python; then
		local native_builddir="${BUILD_DIR}"

		python_compile() {
			emake -C "${BUILD_DIR}" -f Makefile -f - python \
				VPATH="${native_builddir}:${S}" \
				native_builddir="${native_builddir}" \
				libkmod_python_kmod_{kmod,list,module,_util}_la_LIBADD='$(PYTHON_LIBS) $(native_builddir)/libkmod/libkmod.la' \
				<<< 'python: $(pkgpyexec_LTLIBRARIES)'
		}

		python_foreach_impl python_compile
	fi
}

src_install() {
	emake -C "${BUILD_DIR}" DESTDIR="${D}" install

	einstalldocs

	if use python; then
		local native_builddir="${BUILD_DIR}"

		python_install() {
			emake -C "${BUILD_DIR}" DESTDIR="${D}" \
				VPATH="${native_builddir}:${S}" \
				install-pkgpyexecLTLIBRARIES \
				install-dist_pkgpyexecPYTHON
			python_optimize
		}

		python_foreach_impl python_install
	fi

	find "${ED}" -type f -name "*.la" -delete || die

	if use tools; then
		local tool
		for tool in {ins,ls,rm,dep}mod mod{probe,info}; do
    		dosym -r /usr/bin/kmod /usr/sbin/${tool}
  		done
  	fi

	cat <<-EOF > "${T}"/usb-load-ehci-first.conf
	softdep uhci_hcd pre: ehci_hcd
	softdep ohci_hcd pre: ehci_hcd
	EOF

	insinto /usr/lib/modprobe.d
	# bug #260139
	doins "${T}"/usb-load-ehci-first.conf

	newinitd "${FILESDIR}"/kmod-static-nodes-r1 kmod-static-nodes
}

pkg_postinst() {
	if [[ -L ${EROOT}/etc/runlevels/boot/static-nodes ]]; then
		ewarn "Removing old conflicting static-nodes init script from the boot runlevel"
		rm -f "${EROOT}"/etc/runlevels/boot/static-nodes
	fi

	# Add kmod to the runlevel automatically if this is the first install of this package.
	if [[ -z ${REPLACING_VERSIONS} ]]; then
		if [[ ! -d ${EROOT}/etc/runlevels/sysinit ]]; then
			mkdir -p "${EROOT}"/etc/runlevels/sysinit
		fi
		if [[ -x ${EROOT}/etc/init.d/kmod-static-nodes ]]; then
			ln -s /etc/init.d/kmod-static-nodes "${EROOT}"/etc/runlevels/sysinit/kmod-static-nodes
		fi
	fi

	if [[ -e ${EROOT}/etc/runlevels/sysinit ]]; then
		if ! has_version sys-apps/systemd && [[ ! -e ${EROOT}/etc/runlevels/sysinit/kmod-static-nodes ]]; then
			ewarn
			ewarn "You need to add kmod-static-nodes to the sysinit runlevel for"
			ewarn "kernel modules to have required static nodes!"
			ewarn "Run this command:"
			ewarn "\trc-update add kmod-static-nodes sysinit"
		fi
	fi
}
