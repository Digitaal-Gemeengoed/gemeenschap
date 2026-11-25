# Het logo van de organisatie links in de kop van Redmine, met een link naar
# de hoofdpagina (https://<DOMEIN>/). De naam van Redmine zelf blijft naar de
# start van Projecten linken.
require_relative 'lib/dg_kop_hooks'

Redmine::Plugin.register :dg_kop do
  name 'Kop met link naar de hoofdpagina'
  author 'Gemeenschapsplatform (EUPL)'
  description 'Logo en link naar de hoofdpagina in de kop'
  version '1.0.0'
end
