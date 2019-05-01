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

Let's load it with Pandas!

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
from ccsv.wrappers import csv2df

df = csv2df('./data/imdb.csv')
df
```

🎉

## Other Examples

We'll compare CleverCSV to the built-in Python CSV module and to Pandas and 
show how these are not as robust as CleverCSV. These files are of course 
selected for this tutorial, because it wouldn't be very interesting to show 
files where both methods are correct.

The example CSV files all come from MIT-licensed GitHub repositories, and the 
URLs point directly to the source files.

First we'll define some functions for easy comparisons.

```python
import csv
import ccsv
import io
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
    except csv.Error:
        print(colored("No result from the Python CSV Sniffer", "red"))

def detect_url(content, verbose=True):
    """ Utility to run the CleverCSV detector on a CSV file at a URL """
    # We have designed CleverCSV to be a drop-in replacement for the CSV module
    try:
        dialect = ccsv.Sniffer().sniff(content, verbose=verbose)
        print("CleverCSV detected: delimiter = %r, quotechar = %r" % (dialect.delimiter, 
                                                                      dialect.quotechar))
    except ccsv.Error:
        print(colored("No result from CleverCSV", "red"))

def pandas_url(content):
    """ Wrapper around pandas.read_csv(). """
    buf = io.StringIO(content)
    try:
        # by default, this is what pandas.read_csv does to detect the delimiter
        # this is incorrect, only when read_csv(sep=None) will pandas detect
        dialect = csv.Sniffer().sniff(buf.readline())
    except csv.Error:
        print(colored("Error occurred sniffing the dialect", "red"))
        return
    print(
        "Pandas detected: delimiter = %r, quotechar = %r"
        % (dialect.delimiter, '"')
    )
    buf.seek(0)
    try:
        df = pd.read_csv(buf)
        display(df)
    except pd.errors.ParserError:
        print(colored("ParserError from pandas.", "red"))


def compare(url, verbose=False, n_preview=10):
    content = page(url)
    head(content, num=n_preview)
    print("\n1. Running Python Sniffer")
    sniff_url(content)
    print("\n2. Running Pandas")
    pandas_url(content)
    print("\n3. Running CleverCSV")
    detect_url(content, verbose=verbose)
```


## Example 1: No output from Python Sniffer

The first file we'll look at is a simple CSV file that uses the semicolon as delimiter. 


```python
compare("https://raw.githubusercontent.com/grezesf/Research/17b1e829d1d4b8954661270bd8b099e74bb45ce7/Reservoirs/Task0_Replication/code/preprocessing/factors.csv")
```

As we can see, the Python CSV sniffer fails on this one, even though the 
formatting doesn't seem to be that uncommon. CleverCSV handles this file 
correctly.

## Example 2: Incorrect output from Python Sniffer

The next example is quite a long file with a lot of potential delimiters. In 
total, CleverCSV considers 180 different dialects on this file and determines 
the best dialect by computing a pattern score and a type score. The pattern 
score is related to how many cells we have per row given a certain dialect, 
and the type score reflects whether the cells in the parsed file have known 
data types (such as integer, date, string, etc.). 

If you want to see the output of CleverCSV while it runs the detection, you 
can set ``verbose=True`` in the next line.

```python
compare("https://raw.githubusercontent.com/agh-glk/pyconpl2013-nlp/37f6f50a45fc31c1a5ad25010fff681a8ce645b8/gsm.csv", verbose=False)
```

Note that CleverCSV is a bit slower than the Python Sniffer. This is the focus 
of our ongoing development efforts and is also affected by running Python 
through Jupyter. But let's not forget that at least CleverCSV is correct!

## Conclusion

Below are some more examples, but I think you'll get the idea by now. 
CleverCSV is much more robust against messy CSV files and is an easy to use 
drop-in replacement for the Python csv module. Just replace ``import csv`` by 
``import ccsv`` in your code!

We're still working on adding some more features to CleverCSV and speeding up 
and improving the dialect detection algorithm. One of the novel features that 
we added is a ``clevercsv`` command line executable with the following 
commands:

- ``detect`` to run dialect detection directly from the command line

- ``view`` to open a CSV file in a table viewer after automatic detection of 
  the dialect

- ``standardize`` to convert a CSV file in a messy format to the standard CSV 
  format


We hope you find CleverCSV useful! If you encounter any issues or files where 
CleverCSV fails, please leave a comment on GitHub.

## Further Examples


```python
# No result from Python (note that this file says it uses "|" as separator, but actually uses ","!)
compare("https://raw.githubusercontent.com/queq/just-stuff/c1b8714664cc674e1fc685bd957eac548d636a43/pov/TopFixed/build/project_r_pad.csv", n_preview=30)
```

```python
# Python says '\r' (carriage return) is the delimiter!
compare("https://raw.githubusercontent.com/HAYASAKA-Ryosuke/TodenGraphDay/8f052219d037edabebd488e5f6dc2ddbe8367dc1/juyo-j.csv")
```

```python
# No result from Python csv
compare("https://raw.githubusercontent.com/philipmcg/minecraft-service-windows/774892ff0c27a76b6db20ba3750149c19b7a3351/MinecraftService/MinecraftService/gcsv_sample.csv")
```

```python
# Incorrect delimiter from Python csv
compare("https://raw.githubusercontent.com/OptimusGitEtna/RestSymf/635e4ad8a288cde64b306126c986213de71a4f4a/Python-3.4.2/Doc/tools/sphinxext/susp-ignored.csv")
```
