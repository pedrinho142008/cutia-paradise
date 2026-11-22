from pathlib import Path

arquivos = ["index.html", "cozinha.html"]

scripts = '''
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="config.js"></script>
<script src="auth.js"></script>
'''

for nome in arquivos:
    caminho = Path(nome)
    html = caminho.read_text(encoding="utf-8")

    if "auth.js" in html:
        print(f"{nome}: já possui auth.js.")
        continue

    marcador = "</head>"
    if marcador.lower() not in html.lower():
        print(f"{nome}: não encontrei </head>. Nenhuma alteração feita.")
        continue

    posicao = html.lower().rfind(marcador)
    html = html[:posicao] + scripts + "\n" + html[posicao:]

    caminho.write_text(html, encoding="utf-8")
    print(f"{nome}: scripts adicionados antes de </head>.")

