package main

import (
	"os"
	"strings"
	"unicode"
	"unicode/utf8"
)

// Gegevens van de organisatie uit organisatie.yml (via de omgeving, ORG_*).

// orgNaam is de naam van de organisatie, zoals bezoekers hem zien.
func orgNaam() string {
	if v := strings.TrimSpace(os.Getenv("ORG_NAAM")); v != "" {
		return v
	}
	return "Gemeenschapsplatform"
}

// orgSoort is wat voor organisatie het is ("coöperatie", "vereniging"); met
// hoofdletter voor een kop of label. De ruimte en de chatkamer heten intern
// altijd "cooperatie"; dit is alleen de tekst.
func orgSoort(hoofdletter bool) string {
	s := strings.TrimSpace(os.Getenv("ORG_SOORT"))
	if s == "" {
		s = "organisatie"
	}
	if hoofdletter {
		r, n := utf8.DecodeRuneInString(s)
		return string(unicode.ToUpper(r)) + s[n:]
	}
	return s
}
