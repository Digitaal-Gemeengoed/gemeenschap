# frozen_string_literal: true

class DgKopHooks < Redmine::Hook::ViewListener
  def site
    "https://#{ENV.fetch('DOMEIN', '')}"
  end

  def view_layouts_base_html_head(_context = {})
    <<~HTML.html_safe
      <style>
        #header .dg-merk { float: left; margin: 0 .75rem 0 0; line-height: 0; }
        #header .dg-merk img { width: 40px; height: 40px; }
        #header h1 { display: flex; align-items: center; }
      </style>
    HTML
  end

  def view_layouts_base_body_bottom(_context = {})
    s = ERB::Util.html_escape(site)
    <<~HTML.html_safe
      <script>
        (function () {
          var kop = document.querySelector('#header h1');
          if (!kop || kop.querySelector('.dg-merk')) return;
          var a = document.createElement('a');
          a.className = 'dg-merk';
          a.href = '#{s}/';
          a.title = 'Naar de hoofdpagina';
          a.innerHTML = '<img src="/huisstijl/icoon.png" alt="Naar de hoofdpagina">';
          kop.insertBefore(a, kop.firstChild);
        })();
      </script>
    HTML
  end
end
