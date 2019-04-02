url_pat='https://cloud.r-project.org/web/checks/check_results_%s.html\n'

# starting
echo "scraping cran maintainer check pages"

# outputs txt file of maintainers
ruby cran_maintainers.rb 

# get all pages
cat maintainers.txt | xargs printf $url_pat | ganda --connect-timeout 10 --throttle 40 -o /tmp/mainthtmls
echo "done"
