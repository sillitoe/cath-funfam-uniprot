# CATH / UniProtKB

**Note:** this repo currently contains at least one large data file (~70MB). This may get moved over to [Git LFS](https://git-lfs.github.com/) at some point in the future.

This project has been created to help various aspects of integrating CATH FunFams and UniProtKB, including:

 * Choosing suitable names for CATH FunFams (based on UniProtKB annotations)
 * Mapping UniProtKB entries to CATH FunFams


## Mapping Data

This repository contains data files in the form of tab-separated text files (with some automatically generated meta data in the headers).

#### FunFam Names

```
./data/funfam_names.v4_1_0.tsv.gz
```

This is a list of all the FunFam names as they currently stand in CATH v4.1.

```
> zcat ./data/funfam_names.v4_1_0.tsv.gz | head
# FILE            funfam_names.v4_1_0.tsv
# DESCRIPTION     Create a list of the FunFam names in CATH v4_1_0
# CREATED_BY      ucbcisi
# GENERATED       Thu Mar  2 21:31:49 2017
# HOSTNAME        bsmlx53
# GIT_LAST_COMMIT 705343229e07c02aa26dbce4a426de91d4e495eb (Thu Mar 2 21:22:13 2017 +0000)
# FORMAT          FUNFAM_ID     NAME
1.10.10.10/FF/56                Putative replication protein C
1.10.10.10/FF/481               ATP-dependent DNA helicase Q-like SIM
1.10.10.10/FF/1225              DEP domain-containing protein 7
```

#### FunFam to UniProtKB sequences

```
./data/funfam_uniprot_mapping.v4_1_0.tsv.gz
```

Provides a mapping of all the domains found in CATH FunFam to their 
UniProtKB entries.

```
> zcat ./data/funfam_uniprot_mapping.v4_1_0.tsv.gz | head
# FILE            funfam_uniprot_mapping.v4_1_0.tsv
# DESCRIPTION     Create a mapping between uniprot accessions
# CREATED_BY      ucbcisi
# GENERATED       Thu Mar  2 20:59:30 2017
# HOSTNAME        bsmlx53
# GIT_LAST_COMMIT 03fcbdb073cefc8dca53d21e552d6acf6781cdc8 (Thu Mar 2 19:44:55 2017 +0000)
# FORMAT          FUNFAM_ID     MEMBER_ID       UNIPROT_ACC     DESCRIPTION
1.10.10.10/FF/56        c590ded82159d8d59d18c6f2885a5761/40-172_215-246 P55391          Putative replication protein C
1.10.10.10/FF/481       5ad1400176f956f6ff45a16115a61803/601-780        Q9FT69          ATP-dependent DNA helicase Q-like SIM
1.10.10.10/FF/481       67283d4022905118dc23abda563d6a19/600-777        D7M5J3          Predicted protein
```

#### Generating this data


```
./script/generate_data.pl
```

Note: Requires database and libraries local to UCL.

   
## FunFam Naming Protocol

The protocol responsible for assigning names to FunFams in CATH v4.1 was 
designed to meet the following objectives:

 * Assigning names must be completely automated
 * An ideal name will be:
    1. biologically meaningful
    1. unique
    1. representative of all the sequences in a cluster
 * Procedure should be simple and reproducible
 
#### Original protocol (CATH v4.1)

The following protocol is far from perfect, however it is simple and it matched the objectives better than any other method.

For each FunFam:

 1. Associate a UniProtKB description for each member
 * Split descriptions into individual "terms"
 * Normalise "terms" (lowercase, remove common words, etc)
 * Generate running total of how often each terms occurs in the FunFam
 * Go back and score each description based on the scores for each term
 * Normalise each description based on number of words (descriptions are penalised as they go further away from 6-8 words)


## FAQ

** What is a FunFam? **

A FunFam (Functional Family) is a collection of protein domains within a Homologous Superfamily in CATH that have been predicted to
perform the similar function. These domains can come from one of two sources:

 * **CATH**: sequences from known PDB structures that have been manually chopped into structural domains
 * **Gene3D**: sequences of predicted structural domains

Both of these types of domain (PDB and predicted) can be mapped to a location on a protein sequence in UniProtKB. 

** Distribution of FunFams **

The most recent version of CATH contains more than 100,000 FunFam clusters, although many of these clusters only contain a small number of sequences. 
A subset of around 30,000 of these FunFams have a high information content and have been "frozen" ie there is sufficient overall sequence diversity within 
the cluster to provide meaningful information on conserved positions.


