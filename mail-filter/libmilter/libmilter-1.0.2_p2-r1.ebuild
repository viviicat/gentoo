# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

# Note: please bump this together with mail-mta/sendmail

inherit toolchain-funcs

# This library is part of sendmail, but it does not share the version number with it.
# In order to find the right libmilter version number, check SMFI_VERSION definition
# that can be found in ${S}/include/libmilter/mfapi.h (see also SM_LM_VRS_* defines).
# For example, version 1.0.1 has a SMFI_VERSION of 0x01000001.
SENDMAIL_VER=8.17.1

DESCRIPTION="The Sendmail Filter API (Milter)"
HOMEPAGE="http://www.sendmail.org/"
SRC_URI="ftp://ftp.sendmail.org/pub/sendmail/sendmail.${SENDMAIL_VER}.tar.gz"
S="${WORKDIR}/sendmail-${SENDMAIL_VER}"

LICENSE="Sendmail"
# We increment _pN when a new sendmail tarball comes out
# We change the actual "main version" (1.0.2 at time of writing) when the version
# of libmilter included in the tarball changes.
SLOT="0/$(ver_cut 1-3)"
KEYWORDS="~alpha amd64 ~arm arm64 ~hppa ~ia64 ~ppc ~ppc64 ~riscv ~s390 ~sparc x86"
IUSE="ipv6 poll"

RDEPEND="!<mail-mta/sendmail-8.16.1"

# build system patch copied from sendmail ebuild
PATCHES=(
	"${FILESDIR}"/sendmail-8.16.1-build-system.patch
	"${FILESDIR}"/${PN}-sharedlib.patch
)

src_prepare() {
	default

	local ENVDEF="-DNETUNIX -DNETINET -DHAS_GETHOSTBYNAME2=1"

	use ipv6 && ENVDEF+=" -DNETINET6"
	use poll && ENVDEF+=" -DSM_CONF_POLL=1"

	if use elibc_musl; then
		use ipv6 && ENVDEF+=" -DNEEDSGETIPNODE"

		eapply "${FILESDIR}"/${PN}-musl-stack-size.patch
		eapply "${FILESDIR}"/${PN}-musl-disable-cdefs.patch
	fi

	sed -e "s|@@CC@@|$(tc-getCC)|" \
		-e "s|@@CFLAGS@@|${CFLAGS}|" \
		-e "s|@@ENVDEF@@|${ENVDEF}|" \
		-e "s|@@LDFLAGS@@|${LDFLAGS}|" \
		"${FILESDIR}"/gentoo.config.m4 > devtools/Site/site.config.m4 \
		|| die "failed to generate site.config.m4"
}

src_compile() {
	emake -j1 -C libmilter AR="$(tc-getAR)" MILTER_SOVER=${PV}
}

src_install() {
	dodir /usr/$(get_libdir)

	local emakeargs=(
		DESTDIR="${D}" LIBDIR="/usr/$(get_libdir)"
		MANROOT=/usr/share/man/man
		SBINOWN=root SBINGRP=0 UBINOWN=root UBINGRP=0
		LIBOWN=root LIBGRP=0 GBINOWN=root GBINGRP=0
		MANOWN=root MANGRP=0 INCOWN=root INCGRP=0
		MSPQOWN=root CFOWN=root CFGRP=0
		MILTER_SOVER="$(ver_cut 1-3)"
	)
	emake -C obj.*/libmilter "${emakeargs[@]}" install

	dodoc libmilter/README

	docinto html
	dodoc -r libmilter/docs/.

	if [[ ${PV} != $(ver_cut 1-3) ]] ; then
		# Move the .so file to the more specific name so it becomes a chain like
		# .so -> .so.1.0.2 -> .so.1.0.2_p2, otherwise ldconfig can get confused
		# (bug #864563).
		#
		# See comment above ${SLOT} definition above.
		mv "${ED}"/usr/$(get_libdir)/"${PN}.so.$(ver_cut 1-3)" "${ED}"/usr/$(get_libdir)/${PN}.so.${PV}
		dosym ${PN}.so.${PV} /usr/$(get_libdir)/${PN}.so.$(ver_cut 1-3)
	fi

	find "${ED}" -name '*.a' -delete || die
}
