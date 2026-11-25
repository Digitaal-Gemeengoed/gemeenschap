<?php
/**
 * Het standaardthema van het gemeenschapsplatform: een kindthema van BuddyX.
 *
 * Naam, kleuren, logo en de teksten in de voet komen uit organisatie.yml en
 * huisstijl/ (via dg_org() in dg-platform.php). Wat in de Customizer staat,
 * telt voor deze instellingen niet: een wijziging doe je in organisatie.yml.
 * (De map heet nog digitaalgemeengoed: WordPress bewaart de menu's en het logo
 * onder de naam van de map.)
 *
 * @package Gemeenschapsplatform
 */

defined( 'ABSPATH' ) || exit;

/**
 * De kleuren van BuddyX: accent en accent_donker uit organisatie.yml. Kies ze
 * zo dat witte tekst op de knoppen WCAG AA haalt (contrast ≥ 4,5).
 */
function dg_thema_kleuren(): array {
	$a = function_exists( 'dg_org' ) ? dg_org( 'accent' ) : '#0066cc';
	$d = function_exists( 'dg_org' ) ? dg_org( 'accent_donker' ) : '#003c7a';
	return array(
		'site_primary_color'                  => $a,
		'site_links_color'                    => $a,
		'site_links_focus_hover_color'        => $d,
		'site_title_hover_color'              => $a,
		'site_buttons_background_color'       => $a,
		'site_buttons_background_hover_color' => $d,
		'site_buttons_border_color'           => $a,
		'site_buttons_border_hover_color'     => $d,
		'site_buttons_text_color'             => '#ffffff',
		'site_buttons_text_hover_color'       => '#ffffff',
		'site_footer_links_hover_color'       => $a,
		'site_copyright_links_hover_color'    => $a,
	);
}
// BuddyX leest zijn instellingen in één keer (get_theme_mods), dus de vaste
// waarden gaan over de opgeslagen instellingen heen, niet per instelling.
// De privacyverklaring staat al in het menu "Voet". Geen zijbalken: de pagina's
// gebruiken de hele breedte (anders toont BuddyX de standaardwidgets van een
// nieuwe installatie, zoals Recent Posts, naast de opening).
add_filter(
	'option_theme_mods_' . get_stylesheet(),
	static fn( $mods ) => array_merge(
		(array) $mods,
		dg_thema_kleuren(),
		array(
			'site_custom_colors'          => true,
			// Breed genoeg voor logo, ondertitel en het hele hoofdmenu (anders "More").
			'site_container_width'        => '1380px',
			'site_copyright_privacy_link' => 'off',
			'sidebar_option'              => 'none',
			'single_post_sidebar_option'  => 'none',
			'buddypress_sidebar_option'   => 'none',
			'buddypress_members_sidebar_option' => 'none',
			'buddypress_groups_sidebar_option'  => 'none',
			'bbpress_sidebar_option'      => 'none',
		)
	)
);

// De voet: het menu "Voet" uit inhoud/menu.md en een regel over wie we zijn.
add_filter( 'theme_mod_site_copyright_text', 'dg_voet' );

/**
 * De voet uit het menu "Voet" (inhoud/menu.md): links het logo met een korte
 * omschrijving, dan een kolom per punt zonder link met de punten eronder, en
 * onderaan de punten met een link.
 */
function dg_voet(): string {
	$items    = wp_get_nav_menu_object( 'Voet' ) ? (array) wp_get_nav_menu_items( 'Voet' ) : array();
	$kolommen = array();
	$onder    = array();
	foreach ( $items as $item ) {
		if ( (int) $item->menu_item_parent ) {
			$kolommen[ (int) $item->menu_item_parent ]['links'][] = $item;
		} elseif ( '#' === $item->url ) {
			$kolommen[ (int) $item->ID ]['titel'] = $item->title;
		} else {
			$onder[] = $item;
		}
	}
	$link = static fn( $item ) => '<a href="' . esc_url( $item->url ) . '">' . esc_html( $item->title ) . '</a>';
	// De naam op twee regels (bij de eerste spatie), zoals in het logo.
	$naam   = esc_html( dg_org( 'naam' ) );
	$naam   = preg_replace( '/ /', '<br>', $naam, 1 );
	$slogan = dg_org( 'slogan' );
	$over   = dg_org( 'over' );
	$html   = '<div class="dg-voet-boven"><div class="dg-voet-merk"><img src="' . esc_url( home_url( '/huisstijl/logo.png' ) ) . '" alt="" height="78"><div><strong>' . $naam . '</strong>' . ( '' !== $slogan ? '<span>' . esc_html( $slogan ) . '</span>' : '' ) . '</div>'
		. ( '' !== $over ? '<p>' . esc_html( $over ) . '</p>' : '' ) . '</div>';
	foreach ( $kolommen as $kolom ) {
		if ( empty( $kolom['titel'] ) || empty( $kolom['links'] ) ) {
			continue;
		}
		$html .= '<div class="dg-voet-kolom"><h3>' . esc_html( $kolom['titel'] ) . '</h3><ul>' . implode( '', array_map( static fn( $i ) => '<li>' . $link( $i ) . '</li>', $kolom['links'] ) ) . '</ul></div>';
	}
	$voet  = dg_org( 'voet' );
	$html .= '</div><div class="dg-voet-onder"><span>© ' . esc_html( wp_date( 'Y' ) . ' ' . dg_org( 'organisatie' ) . ( '' !== $voet ? ' · ' . $voet : '' ) ) . '</span>'
		. ( $onder ? '<span class="dg-voet-links">' . implode( '', array_map( $link, $onder ) ) . '</span>' : '' ) . '</div>';
	return $html;
}

add_action(
	'wp_enqueue_scripts',
	static function () {
		wp_enqueue_style( 'digitaalgemeengoed', get_stylesheet_uri(), array(), wp_get_theme()->get( 'Version' ) );
	},
	20
);

// "Log in" in de kop heet bij ons "Aanmelden" (het ontwerp; zo heet het ook in Keycloak).
add_filter(
	'gettext_buddyx',
	static fn( $vertaling, $tekst ) => 'Log in' === $tekst ? 'Aanmelden' : $vertaling,
	10,
	2
);

// De zwarte WordPress-werkbalk staat uit: zie wordpress/dg-gemeenschap.php
// ("De achterkant van WordPress is dicht").

// Een pagina die begint met een opening (::: held in inhoud/): geen titelbalk van
// BuddyX met kruimelpad, want de opening heeft de titel al.
function dg_heeft_held(): bool {
	if ( ! is_page() ) {
		return false;
	}
	$post = get_queried_object();
	return $post instanceof WP_Post && str_contains( $post->post_content, 'dg-held' );
}
add_action(
	'wp',
	static function () {
		if ( dg_heeft_held() ) {
			remove_action( 'buddyx_sub_header', 'buddyx_sub_header' );
		}
	}
);
add_filter( 'body_class', static fn( $klassen ) => dg_heeft_held() ? array_merge( $klassen, array( 'dg-met-held' ) ) : $klassen );

// Emoji zoals het systeem ze toont: geen script en geen plaatjes van s.w.org
// (scheelt een verzoek naar een andere site bij elke pagina; de reacties op
// berichten zijn emoji).
remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
remove_action( 'wp_print_styles', 'print_emoji_styles' );
remove_filter( 'the_content_feed', 'wp_staticize_emoji' );
remove_filter( 'comment_text_rss', 'wp_staticize_emoji' );
remove_filter( 'wp_mail', 'wp_staticize_emoji_for_email' );
add_filter( 'emoji_svg_url', '__return_false' );
