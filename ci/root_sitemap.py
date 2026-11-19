# Writes /sitemap.xml at the root of the gh-pages worktree (the current folder).
# Both deploys run it: ci/docs-redirects.sh (docs tag) and ci/blog-deploy.sh
# (blog push to main). So the root sitemap always has the newest docs and
# the newest blog posts.
#
# It holds:
# - the pages of the /latest/ sitemap. Their links point to /latest/,
#   where canonical URLs point.
# - the llms files, because some AI tools read only the sitemap and never
#   try /llms.txt.
# - the pages of the /blog/ sitemap.
import json, os, re

versions = json.load(open('versions.json'))
home = 'latest' if os.path.isdir('latest') else versions[0]['version']

with open(os.path.join(home, 'sitemap.xml')) as f:
    sitemap = f.read()
# The llms files get the same date as the pages (the build date).
lastmod = re.search(r'<lastmod>[^<]*</lastmod>', sitemap)
lastmod = '         %s\n' % lastmod.group(0) if lastmod else ''
extra = ''.join('    <url>\n         <loc>https://dartondox.dev/%s</loc>\n'
                '%s    </url>\n' % (name, lastmod)
                for name in ('llms.txt', 'llms-full.txt'))
if os.path.isfile('blog/sitemap.xml'):
    with open('blog/sitemap.xml') as f:
        extra += ''.join('    %s\n' % url for url in
                         re.findall(r'<url>.*?</url>', f.read(), re.S))
with open('sitemap.xml', 'w') as f:
    f.write(sitemap.replace('</urlset>', extra + '</urlset>', 1))
