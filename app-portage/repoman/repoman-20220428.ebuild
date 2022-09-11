# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{8..11} )

inherit distutils-r1

DESCRIPTION="Repoman is a Quality Assurance tool for Gentoo ebuilds"
HOMEPAGE="https://wiki.gentoo.org/wiki/Project:Portage"

if [[ ${PV} == *9999 ]]; then
	EGIT_REPO_URI="https://github.com/gentoo/portage.git"
	inherit git-r3
	S="${WORKDIR}/${P}/repoman"
else
	SNAPSHOT=605ad0d675a64eb39144122cf284100192cdfea0
	SRC_URI="https://github.com/gentoo/portage/archive/${SNAPSHOT}.tar.gz -> portage-${PV}.tar.gz"
	S=${WORKDIR}/portage-${SNAPSHOT}/repoman
fi

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="amd64 arm64"

DEPEND="
	dev-python/lxml[${PYTHON_USEDEP}]
	dev-python/pyyaml[${PYTHON_USEDEP}]
"

python_prepare_all() {
	distutils-r1_python_prepare_all
}

python_test() {
	esetup.py test
}

python_install() {
	# Install sbin scripts to bindir for python-exec linking
	# they will be relocated in pkg_preinst()
	distutils-r1_python_install \
		--system-prefix="${EPREFIX}/usr" \
		--bindir="$(python_get_scriptdir)" \
		--sbindir="$(python_get_scriptdir)" \
		--sysconfdir="${EPREFIX}/etc" \
		"${@}"

	rm -r "${ED}"/usr/share/doc
}
