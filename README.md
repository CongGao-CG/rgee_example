### Using conda to create an environment called env-rgee

```bash
conda create --name env-rgee
```

### Activating the conda env env-rgee

```bash
source ~/miniconda3/bin/activate env-rgee
```

### Installing R and R packages

```bash
conda install -c conda-forge r-tidyverse r-rgee
```

### Installing Python and Python packages

```bash
conda install -c conda-forge earthengine-api==0.1.370 numpy
```

### Configuring the rgee package by add the following to ~/.Renviron file

```bash
RETICULATE_PYTHON=~/miniconda3/envs/env-rgee/bin/python
EARTHENGINE_GCLOUD=~/miniconda3/envs/env-rgee/bin/
```

### You made it!

```bash
(env-rgee) ➜  ~ R

R version 4.4.3 (2025-02-28) -- "Trophy Case"
Copyright (C) 2025 The R Foundation for Statistical Computing
Platform: aarch64-apple-darwin20.0.0

R is free software and comes with ABSOLUTELY NO WARRANTY.
You are welcome to redistribute it under certain conditions.
Type 'license()' or 'licence()' for distribution details.

  Natural language support but running in an English locale

R is a collaborative project with many contributors.
Type 'contributors()' for more information and
'citation()' on how to cite R or R packages in publications.

Type 'demo()' for some demos, 'help()' for on-line help, or
'help.start()' for an HTML browser interface to help.
Type 'q()' to quit R.

> library(rgee)
> ee_Initialize()
── rgee 1.1.7 ─────────────────────────────────────────────────────────────────────────── earthengine-api 0.1.370 ── 
 ✔ user: not_defined 
 ✔ Initializing Google Earth Engine:  DONE!
 ✔ Earth Engine account: users/cnggao 
 ✔ Python Path: /Users/cg6622/miniconda3/envs/env-rgee/bin/python 
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────── 
> 
```

#### *when you first run $ee_Initialize$, you will see

```bash
> ee_Initialize()                                                                                                                           
── rgee 1.1.7 ─────────────────────────────────────────────────────────────────────────────────────────────────────────────── earthengine-api 0.1.370 ──                                                                                                                                                        
 ✔ user: not_defined                                                                                                                                    
 ✔ Initializing Google Earth Engine:To authorize access needed by Earth Engine, open the following URL in a web browser and follow the instructions. If the web browser does not start automatically, please manually browse the URL below.

    https://code.earthengine.google.com/client-auth?scopes=https%3A//www.googleapis.com/auth/earthengine%20https%3A//www.googleapis.com/auth/devstorage.full_control&request_id=1pjjdBtaQUMdaCAWqMw3NmTHJe25Gi_AptGnoAhHQEE&tc=QyZmnw5dWZmwo3mPr4tzkouHOGzS8fGsdwJUOycYDQo&cc=vmpxTSsW8E0woD-yOIXRrl3EijfwgPlQsb8h26ersEw

The authorization workflow will generate a code, which you should paste in the box below.
Enter verification code: 
```
