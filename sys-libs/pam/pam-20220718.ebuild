# Distributed under the terms of the GNU General Public License v2

EAPI=7

MY_P="Linux-${PN^^}-${PV}"

# Avoid QA warnings
# Can reconsider w/ EAPI 8 and IDEPEND, bug #810979
TMPFILES_OPTIONAL=1

inherit autotools db-use flag-o-matic toolchain-funcs usr-ldscript multilib-minimal

DESCRIPTION="Linux-PAM (Pluggable Authentication Modules)"
HOMEPAGE="https://github.com/linux-pam/linux-pam"

SNAPSHOT=510e825ef130a843663115ec510b1237ea4708f4
SRC_URI="${HOMEPAGE}/archive/${SNAPSHOT}.tar.gz -> ${P}.tar.gz"
S=${WORKDIR}/linux-${PN}-${SNAPSHOT}

LICENSE="|| ( BSD GPL-2 )"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 hppa ~ia64 ~loong ~m68k ~mips ppc ppc64 ~riscv ~s390 sparc x86 ~amd64-linux ~x86-linux"
IUSE="audit berkdb debug nis selinux"

BDEPEND="
	dev-libs/libxslt
	sys-devel/flex
	sys-devel/gettext
	virtual/pkgconfig
	virtual/yacc
"

DEPEND="
	>=virtual/libintl-0-r1[${MULTILIB_USEDEP}]
	audit? ( >=sys-process/audit-2.2.2[${MULTILIB_USEDEP}] )
	berkdb? ( >=sys-libs/db-4.8.30-r1:=[${MULTILIB_USEDEP}] )
	selinux? ( >=sys-libs/libselinux-2.2.2-r4[${MULTILIB_USEDEP}] )
	nis? ( net-libs/libnsl:=[${MULTILIB_USEDEP}]
	>=net-libs/libtirpc-0.2.4-r2:=[${MULTILIB_USEDEP}] )"

RDEPEND="${DEPEND}"

PDEPEND=">=sys-auth/pambase-20200616"

src_prepare() {
	default
	touch ChangeLog || die
	eautoreconf
}

multilib_src_configure() {
	# Do not let user's BROWSER setting mess us up. #549684
	unset BROWSER

	# This whole weird has_version libxcrypt block can go once
	# musl systems have libxcrypt[system] if we ever make
	# that mandatory. See bug #867991.
	if use elibc_musl && ! has_version sys-libs/libxcrypt[system] ; then
		# Avoid picking up symbol-versioned compat symbol on musl systems
		export ac_cv_search_crypt_gensalt_rn=no

		# Need to avoid picking up the libxcrypt headers which define
		# CRYPT_GENSALT_IMPLEMENTS_AUTO_ENTROPY.
		cp "${ESYSROOT}"/usr/include/crypt.h "${T}"/crypt.h || die
		append-cppflags -I"${T}"
	fi

	local myconf=(
		CC_FOR_BUILD="$(tc-getBUILD_CC)"
		--with-db-uniquename=-$(db_findver sys-libs/db)
		--with-xml-catalog="${EPREFIX}"/etc/xml/catalog
		--enable-securedir="${EPREFIX}"/usr/$(get_libdir)/security
		--includedir="${EPREFIX}"/usr/include/security
		--libdir="${EPREFIX}"/usr/$(get_libdir)
		--enable-pie
		--enable-unix
		--disable-prelude
		--disable-doc
		--disable-regenerate-docu
		--disable-static
		--disable-Werror
		$(use_enable audit)
		$(use_enable berkdb db)
		$(use_enable debug)
		$(use_enable nis)
		$(use_enable selinux)
		--enable-isadir='.' #464016
	)
	ECONF_SOURCE="${S}" econf "${myconf[@]}"
}

multilib_src_compile() {
	emake sepermitlockdir="/run/sepermit"
}

multilib_src_install() {
	emake DESTDIR="${D}" install \
		sepermitlockdir="/run/sepermit"

	gen_usr_ldscript -a pam pam_misc pamc
}

multilib_src_install_all() {
	find "${ED}" -type f -name '*.la' -delete || die

	# tmpfiles.eclass is impossible to use because
	# there is the pam -> tmpfiles -> systemd -> pam dependency loop

	dodir /usr/lib/tmpfiles.d

	cat ->>  "${D}"/usr/lib/tmpfiles.d/${CATEGORY}-${PN}.conf <<-_EOF_
		d /run/faillock 0755 root root
	_EOF_
	use selinux && cat ->>  "${D}"/usr/lib/tmpfiles.d/${CATEGORY}-${PN}-selinux.conf <<-_EOF_
		d /run/sepermit 0755 root root
	_EOF_
}
