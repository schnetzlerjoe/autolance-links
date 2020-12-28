using Pkg
Pkg.add("Gumbo")
Pkg.add("HTTP")
Pkg.add("Cascadia")
Pkg.add("DataFrames")

using Gumbo
using HTTP 
using DelimitedFiles 
using Cascadia
using DataFrames

search_term = HTTP.URIs.escapeuri("data")
location = HTTP.URIs.escapeuri("")
start_num = 0

#Define URL to scrape
pre_url = "https://www.indeed.com/jobs?q=" * search_term * "&l=" * location * "&start=" * string(start_num)

url = "http://api.scraperapi.com/?api_key=721e602b2a88af5b771ebd1a0d874c03&url=$pre_url"

#Request url and get response back
res = HTTP.get(url)

#Turn response into parsable html via Gumbo
html = parsehtml(String(res.body))

#Get number of job results from scraped page 
matched = match(r"(?<=of ).*?(?= jobs)", nodeText(eachmatch(Selector("div[id='searchCountPages']"), html.root)[1]))

#Convert number of jobs found to numerical
num_jobs = parse(Float64, replace(matched.match, [',',';'] => ""))

#Create empty array to hold job_links
job_links = []

#Loop through all pages
Threads.@threads for i in range(0, ceil(num_jobs), step = 15)

    ## Begin try
    try

        start_num = i

        #Define URL to scrape
        pre_url = "https://www.indeed.com/jobs?q=" * search_term * "&l=" * location * "&start=" * string(start_num)

        url = "http://api.scraperapi.com/?api_key=721e602b2a88af5b771ebd1a0d874c03&url=$pre_url"

        #Request url and get response back
        res = HTTP.get(url)

        #Turn response into parsable html via Gumbo
        html = parsehtml(String(res.body))

        #Select the result column from table using Cascadia select
        result_col = eachmatch(Selector("td[id='resultsCol']"), html.root)

        #Using Cascadia selector get all divs that contain jobs
        global job_divs = eachmatch(Selector(".title"), html.root)

    ## Begin catch
    catch error

        println(error)

        continue

    ## End try

    end

    #For loop to loop through all the job divs and append job url extension for indeed.com in array
    for job_div in job_divs

        ## Begin try
        try

            #Select all a elements that contain job url extension
            a = eachmatch(Selector("a"), job_div)

            #Add url extension to array
            push!(job_links, a[1].attributes["href"])

        ## Begin catch
        catch error

            println(error)

            continue

        ## End try

        end

    end

    println(string(Threads.threadid()) * ":" * last(job_links) * " $i/" * string(ceil(num_jobs)))

end

writedlm("job_links(data).txt", job_links)