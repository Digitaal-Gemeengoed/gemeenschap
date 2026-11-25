<?php
/**
 * Plugin Name: Gemeenschapsplatform — organisatie en modules
 * Description: Wie de site is en welke modules aan staan, uit organisatie.yml (via de omgeving: ORG_* en DG_MODULES). De andere plugins vragen het hier op. Als eerste geladen (de naam begint met dg-0).
 *
 * dg_module( 'agenda' ) zegt of een module aan staat. Zonder DG_MODULES (een
 * server van vóór 0.23.0) staat alles aan.
 *
 * dg_org( 'naam' ) geeft naam, kort, organisatie, soort, omschrijving, welkom, kleur,
 * kleur_donker en kleur_link. De kleuren staan ook als CSS-variabelen op elke
 * pagina (--dg-kleur, --dg-kleur-donker, --dg-kleur-link), voor elk thema.
 *
 * @package Gemeenschapsplatform
 */

defined( 'ABSPATH' ) || exit;

/** Staat de module aan? "basis" altijd. */
function dg_module( string $module ): bool {
	$lijst = trim( (string) getenv( 'DG_MODULES' ) );
	if ( 'basis' === $module || '' === $lijst ) {
		return true;
	}
	return in_array( $module, array_map( 'trim', explode( ',', $lijst ) ), true );
}

/** Een gegeven van de organisatie (organisatie.yml), met een redelijke terugval. */
function dg_org( string $sleutel ): string {
	$waarde = trim( (string) getenv( 'ORG_' . strtoupper( $sleutel ) ) );
	if ( '' !== $waarde ) {
		return $waarde;
	}
	switch ( $sleutel ) {
		case 'naam':
			return (string) get_option( 'blogname', 'Gemeenschapsplatform' );
		case 'kort':
		case 'organisatie':
			return dg_org( 'naam' );
		case 'omschrijving':
			return (string) get_option( 'blogdescription', '' );
		case 'welkom':
			return dg_org( 'omschrijving' );
		case 'soort':
			return 'organisatie';
		case 'kleur':
			return '#14478f';
		case 'kleur_donker':
			return '#0a2654';
		case 'kleur_link':
			return '#1a56a8';
	}
	return '';
}

/**
 * Wat voor organisatie het is, als zelfstandig naamwoord: "coöperatie",
 * "vereniging" (organisatie.yml, soort). Met $hoofdletter: "Coöperatie".
 * De vaste tag heet intern altijd "cooperatie"; dit is alleen de tekst.
 */
function dg_soort( bool $hoofdletter = false ): string {
	$soort = dg_org( 'soort' );
	return $hoofdletter ? mb_strtoupper( mb_substr( $soort, 0, 1 ) ) . mb_substr( $soort, 1 ) : $soort;
}

/** Het adres van een subdomein van deze site: dg_subdomein( 'kennis' ) = https://kennis.<domein>/. */
function dg_subdomein( string $naam, string $pad = '' ): string {
	return 'https://' . $naam . '.' . wp_parse_url( home_url(), PHP_URL_HOST ) . '/' . ltrim( $pad, '/' );
}

// De kleuren van de huisstijl voor elk thema en elke plugin.
add_action(
	'wp_head',
	static function () {
		$k = array();
		foreach ( array( 'kleur', 'kleur_donker', 'kleur_link' ) as $s ) {
			$v = dg_org( $s );
			if ( preg_match( '/^#[0-9a-fA-F]{6}$/', $v ) ) {
				$k[] = '--dg-' . str_replace( '_', '-', $s ) . ':' . $v;
			}
		}
		if ( $k ) {
			echo '<style id="dg-huisstijl">:root{' . esc_html( implode( ';', $k ) ) . "}</style>\n";
		}
	},
	1
);
