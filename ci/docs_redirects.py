# Run it in the gh-pages worktree, after mike deploy (ci/docs-redirects.sh does).
#
# Before mike, the 2.x pages lived at the site root (/the-basic/routing/).
# Now each version has its own folder, so old links would break.
# This replaces every old root page with a small redirect page to the
# same page in /latest/ (or in /2.x/ when latest does not have it).
# It also writes the root index.html, 404.html and CNAME.
# It runs on every deploy and always gives the same result.
import json, os, shutil

versions = json.load(open('versions.json'))
names = {'.git', '.nojekyll', 'CNAME', 'versions.json', 'robots.txt'}
for v in versions:
    names.add(v['version'])
    names.update(v['aliases'])
home = 'latest' if os.path.isdir('latest') else versions[0]['version']

# The script in <head> moves on before the page is drawn, and keeps
# the ?query and #hash. So the visitor sees no "Redirecting" page.
# The meta refresh and the <noscript> link are for no JavaScript.
def redirect(url):
    return ('<!doctype html><html><head><meta charset="utf-8">'
            '<title>Dox</title>'
            '<link rel="canonical" href="%s">'
            '<script>location.replace("%s" + location.search + location.hash)</script>'
            '<meta http-equiv="refresh" content="0; url=%s">'
            '</head><body><noscript><a href="%s">Open the Dox docs</a></noscript></body></html>'
            % (url, url, url, url))

# collect old pages: every folder with an index.html
pages = set()
def collect(base, prefix):
    for root, _, files in os.walk(base):
        if 'index.html' in files:
            pages.add(os.path.normpath(os.path.join(prefix, os.path.relpath(root, base))))
    pages.discard('.')

for entry in os.listdir('.'):
    if entry in names:
        continue
    if os.path.isdir(entry):
        collect(entry, entry)  # old page or redirect page
        shutil.rmtree(entry)
    else:
        os.remove(entry)  # old index.html, 404.html, sitemap.xml, ...
if os.path.isdir('2.x'):
    collect('2.x', '')

for page in sorted(pages):
    target = home if os.path.isdir(os.path.join(home, page)) else '2.x'
    os.makedirs(page, exist_ok=True)
    with open(os.path.join(page, 'index.html'), 'w') as f:
        f.write(redirect('/%s/%s/' % (target, page.replace(os.sep, '/'))))

with open('index.html', 'w') as f:
    f.write(redirect('/%s/' % home))
with open('404.html', 'w') as f:
    f.write('<!doctype html><html><head><meta charset="utf-8">'
            '<title>Page not found</title></head><body>'
            '<h1>Page not found</h1><p><a href="/%s/">Go to the docs</a></p>'
            '</body></html>' % home)
with open('CNAME', 'w') as f:
    f.write('dartondox.dev\n')
# robots.txt must be at the site root. The sitemap is the one of
# /latest/, where canonical URLs point. Old 2.x docs stay online
# for links, but are not crawled.
with open('robots.txt', 'w') as f:
    f.write('# Algolia-Crawler-Verif: 7556FC76DBDC63BA\n'
            'User-agent: *\n'
            'Allow: /\n'
            'Disallow: /2.x/\n'
            '\n'
            'Sitemap: https://dartondox.dev/latest/sitemap.xml\n')
print('redirect pages:', len(pages))
