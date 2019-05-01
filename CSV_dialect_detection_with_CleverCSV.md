# CSV dialect detection with CleverCSV

**Author**: G.J.J. van den Burg <gvandenburg@turing.ac.uk>

In this note we'll show some examples of using CleverCSV, a package for 
handling messy CSV files. 

We'll compare CleverCSV to the built-in Python CSV module and show how this is 
not as robust as CleverCSV on some examples. The examples will mainly show 
files where the built-in Python CSV module fails to detect the dialect 
correctly. These files are of course selected for this tutorial, because it 
wouldn't be very interesting to show files where both methods are correct. For 
more details on the science behind CleverCSV and a complete and fair 
comparison to other CSV packages, see the 
[paper](https://arxiv.org/abs/1811.11242). On a dataset of over 9300 files 
CleverCSV achieves 97% accuracy on average, with a 21% improvement on messy 
files compared to the Python CSV Sniffer.

The example CSV files all come from MIT-licensed GitHub repositories.


## Setting up


```python
import csv
import ccsv
import io
import requests
import pandas as pd
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
        print("No result from the Python CSV Sniffer")

def detect_url(content, verbose=True):
    """ Utility to run the CleverCSV detector on a CSV file at a URL """
    # We have designed CleverCSV to be a drop-in replacement for the CSV module
    try:
        dialect = ccsv.Sniffer().sniff(content, verbose=verbose)
        print("CleverCSV detected: delimiter = %r, quotechar = %r" % (dialect.delimiter, 
                                                                      dialect.quotechar))
    except ccsv.Error:
        print("No result from CleverCSV")

def pandas_url(url):
    """ Wrapper around pandas.read_csv(). This uses Sniffer internally. """
    try:
        df = pd.read_csv(url)
        display(df)
    except pd.errors.ParserError:
        print("ParserError from pandas.")


def test(url, verbose=False, n_preview=10):
    content = page(url)
    head(content, num=n_preview)
    print("\nRunning Python Sniffer")
    sniff_url(content)
    print("\nRunning Pandas")
    pandas_url(url)
    print("\nRunning CleverCSV")
    detect_url(content, verbose=verbose)
```

## Example 1: No output from Python Sniffer

The first file we'll look at is a simple CSV file that uses the semicolon as delimiter. 


```python
test("https://raw.githubusercontent.com/grezesf/Research/17b1e829d1d4b8954661270bd8b099e74bb45ce7/Reservoirs/Task0_Replication/code/preprocessing/factors.csv")
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
test("https://raw.githubusercontent.com/agh-glk/pyconpl2013-nlp/37f6f50a45fc31c1a5ad25010fff681a8ce645b8/gsm.csv", verbose=False)
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
test("https://raw.githubusercontent.com/queq/just-stuff/c1b8714664cc674e1fc685bd957eac548d636a43/pov/TopFixed/build/project_r_pad.csv", n_preview=20)
```

```python
# Python says '\r' (carriage return) is the delimiter!
test("https://raw.githubusercontent.com/HAYASAKA-Ryosuke/TodenGraphDay/8f052219d037edabebd488e5f6dc2ddbe8367dc1/juyo-j.csv")
```

```python
# No result from Python csv
test("https://raw.githubusercontent.com/philipmcg/minecraft-service-windows/774892ff0c27a76b6db20ba3750149c19b7a3351/MinecraftService/MinecraftService/gcsv_sample.csv")
```

```python
# Incorrect delimiter from Python csv
test("https://raw.githubusercontent.com/OptimusGitEtna/RestSymf/635e4ad8a288cde64b306126c986213de71a4f4a/Python-3.4.2/Doc/tools/sphinxext/susp-ignored.csv")
```
