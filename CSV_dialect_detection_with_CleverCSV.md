# CSV dialect detection with CleverCSV

**Author**: [Gertjan van den Burg](https://gertjan.dev)

In this note we'll show some examples of using CleverCSV, a package for 
handling messy CSV files. We'll start with a motivating example and then show 
some other files where CleverCSV shines. CleverCSV was developed as part of a 
research project on automating data wrangling. It achieves an accuracy of 97% 
on over 9300 real-world CSV files and improves the accuracy on messy files by 
21% over standard tools.

Handy links:

 - [Paper on arXiv](https://arxiv.org/abs/1811.11242)
 - [CleverCSV on GitHub](https://github.com/alan-turing-institute/CleverCSV)
 - [CleverCSV on PyPI](https://pypi.org/project/clevercsv/)
 - [Reproducible Research Repo](https://github.com/alan-turing-institute/CSV_Wrangling/)

## IMDB Movie data

Alice is a data scientist who would like to analyse the movie ratings on IMDB 
for movies of different genres. She found [a dataset shared by a user on 
Kaggle](https://www.kaggle.com/orgesleka/imdbmovies) that contains information 
of over 14,000 movies. Great! 

The data is stored in a CSV file, which is a very common data format for 
sharing tabular data. The first few lines of the file look like this:

```
fn,tid,title,wordsInTitle,url,imdbRating,ratingCount,duration,year,type,nrOfWins,nrOfNominations,nrOfPhotos,nrOfNewsArticles,nrOfUserReviews,nrOfGenre,Action,Adult,Adventure,Animation,Biography,Comedy,Crime,Documentary,Drama,Family,Fantasy,FilmNoir,GameShow,History,Horror,Music,Musical,Mystery,News,RealityTV,Romance,SciFi,Short,Sport,TalkShow,Thriller,War,Western
titles01/tt0012349,tt0012349,Der Vagabund und das Kind (1921),der vagabund und das kind,http://www.imdb.com/title/tt0012349/,8.4,40550,3240,1921,video.movie,1,0,19,96,85,3,0,0,0,0,0,1,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
titles01/tt0015864,tt0015864,Goldrausch (1925),goldrausch,http://www.imdb.com/title/tt0015864/,8.3,45319,5700,1925,video.movie,2,1,35,110,122,3,0,0,1,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
titles01/tt0017136,tt0017136,Metropolis (1927),metropolis,http://www.imdb.com/title/tt0017136/,8.4,81007,9180,1927,video.movie,3,4,67,428,376,2,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0
titles01/tt0017925,tt0017925,Der General (1926),der general,http://www.imdb.com/title/tt0017925/,8.3,37521,6420,1926,video.movie,1,1,53,123,219,3,1,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
titles01/tt0021749,tt0021749,Lichter der Großstadt (1931),lichter der gro stadt,http://www.imdb.com/title/tt0021749/,8.7,70057,5220,1931,video.movie,2,0,38,187,186,3,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0
```

Seems pretty standard, let's load it with Pandas!

```python
%xmode Minimal
import pandas as pd
df = pd.read_csv('./data/imdb.csv')
```

Oh, that doesn't work. Maybe there's something wrong with the file? Let's try 
opening it with the Python CSV reader:

```python
import csv
with open('./data/imdb.csv', 'r', newline='') as fid:
    dialect = csv.Sniffer().sniff(fid.read())
    print("Detected delimiter = %r, quotechar = %r" % (dialect.delimiter, dialect.quotechar))
    fid.seek(0)
    reader = csv.reader(fid, dialect=dialect)
    rows = list(reader)

print("Loaded %i rows." % len(rows))
```

Huh, that's strange, Python thinks the *space* is the delimiter and loads 
13928 rows, but the file should contain 14,762 rows according to the 
documentation.  What's going on here?

It turns out that on the 65th line of the file, there's a movie with the title 
``Dr. Seltsam\, oder wie ich lernte\, die Bombe zu lieben (1964)`` (the German 
version of Dr. Strangelove).  The title has commas in it, that are escaped 
using the ``\`` character!  Why are CSV files so hard? 😑

**CleverCSV to the rescue!**

CleverCSV detects the dialect of CSV files much more accurately than existing 
approaches, and it is therefore robust against these kinds of format 
variations. It even has a wrapper that works with DataFrames!

```python
from clevercsv import csv2df

df = csv2df('./data/imdb.csv')
df
```

Hooray! 🎉

How does it work? CleverCSV searches the space of all possible dialects of a 
file, and computes a *data consistency measure* that quantifies how much the 
resulting table "looks like real data". The consistency measure combines 
patterns of row lengths in the parsing result and the data type of the 
resulting cells.  This mimicks how a human would identify the dialect. If 
you're wondering why this problem is hard, it's because every dialect will 
give you *some* table, but not necessarily the correct one. More details can 
be found [in the paper](https://rdcu.be/bLVur).

## Other Examples

We'll compare CleverCSV to the built-in Python CSV module and to Pandas and 
show how these are not as robust as CleverCSV. Note that Pandas always uses 
the comma as separator, unless it is forced to autodetect the dialect, in 
which case it uses the Python Sniffer on the first line (we don't show that 
here).  These files are of course selected for this tutorial, because it 
wouldn't be very interesting to show files where all methods are correct.

Some files come from the [UK's open government data portal](data.gov.uk) (see 
[the repo for 
sources](https://github.com/alan-turing-institute/CleverCSVDemo/tree/master/data)), 
whereas others come from MIT-licensed GitHub repositories (the URLs point 
directly to the source files).

We'll define some functions for easy comparisons.

```python
import csv
import clevercsv
import io
import os
import requests
import pandas as pd

from termcolor import colored
from IPython.display import display

def page(url):
    """ Get the content of a webpage using requests, assuming UTF-8 encoding """
    page = requests.get(url)
    content = page.content.decode('utf-8')
    return content

def head(content, num=10):
    """ Preview a CSV file """
    print('--- File Preview ---')
    for i, line in enumerate(io.StringIO(content, newline=None)):
        print(line, end='')
        if i == num - 1:
            break
    print('\n---')

def sniff_url(content):
    """ Utility to run the python Sniffer on a CSV file at a URL """
    try:
        dialect = csv.Sniffer().sniff(content)
        print("CSV Sniffer detected: delimiter = %r, quotechar = %r" % (dialect.delimiter,
                                                                        dialect.quotechar))
    except csv.Error as err:
        print(colored("No result from the Python CSV Sniffer", "red"))
        print(colored("Error was: %s" % err, "red"))

def detect_url(content, verbose=True):
    """ Utility to run the CleverCSV detector on a CSV file at a URL """
    # We have designed CleverCSV to be a drop-in replacement for the CSV module
    try:
        dialect = clevercsv.Sniffer().sniff(content, verbose=verbose)
        print("CleverCSV detected: delimiter = %r, quotechar = %r" % (dialect.delimiter, 
                                                                      dialect.quotechar))
    except clevercsv.Error:
        print(colored("No result from CleverCSV", "red"))

def pandas_url(content):
    """ Wrapper around pandas.read_csv(). """
    buf = io.StringIO(content)
    print(
        "Pandas uses: delimiter = %r, quotechar = %r"
        % (',', '"')
    )
    try:
        df = pd.read_csv(buf)
        display(df.head())
    except pd.errors.ParserError:
        print(colored("ParserError from pandas.", "red"))


def compare(input_, verbose=False, n_preview=10):
    if os.path.exists(input_):
      enc = clevercsv.utils.get_encoding(input_)
      content = open(input_, 'r', newline='', encoding=enc).read()
    else:
      content = page(input_)
    head(content, num=n_preview)
    print("\n1. Running Python Sniffer")
    sniff_url(content)
    print("\n2. Running Pandas")
    pandas_url(content)
    print("\n3. Running CleverCSV")
    detect_url(content, verbose=verbose)
```

### Numbers with comma for decimal point

```python
compare('./data/airedale.csv', n_preview=5)
```

You'll notice that Python Sniffer says ``.`` is the delimiter, Pandas is 
correct because the file uses the default comma as separator, and CleverCSV 
detects the dialect correctly as well.

### Tab-separated

```python
compare('./data/milk.csv', n_preview=5)
```

Sniffer and Pandas are incorrect here, but CleverCSV gets it right.

### File with comments

The Python Sniffer gives no result for this file, and Pandas fails because it 
checks for a rectangular table shape.  Note that the text in the comments says 
that the file uses ``|`` as separator, even though it actually uses ``,``!

```python
compare("https://raw.githubusercontent.com/queq/just-stuff/c1b8714664cc674e1fc685bd957eac548d636a43/pov/TopFixed/build/project_r_pad.csv", n_preview=30)
```

### Semi-colon separated

```python
compare("https://raw.githubusercontent.com/grezesf/Research/17b1e829d1d4b8954661270bd8b099e74bb45ce7/Reservoirs/Task0_Replication/code/preprocessing/factors.csv")
```

Sniffer fails outright, Pandas is incorrect because it assumes comma.

### File with multiple tables

```python
compare("https://raw.githubusercontent.com/HAYASAKA-Ryosuke/TodenGraphDay/8f052219d037edabebd488e5f6dc2ddbe8367dc1/juyo-j.csv")
```

Sniffer says ``\r`` (carriage return) is the delimiter!

## Conclusion

We hope you find CleverCSV useful! The package is still in beta, so if you 
encounter any issues or files where CleverCSV fails, please leave a comment on 
GitHub!
