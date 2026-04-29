# `tidyusmacro` update — Dallas Fed trimmed-mean PCE component dataset and helper

This is a self-contained spec. Drop it at the root of the `tidyusmacro`
package, then ask Claude Code to "follow `CLAUDE_dallas_pce.md` to add
the Dallas trimmed-mean PCE data and function."

It adds:

- **`dallasTrimPCEcomponents`** — a 177-component dictionary mapping the
  Dallas Fed tech-notes list to BEA NIPA Table 2.4.4U series codes and
  line numbers.
- **`getDallasTrimPCE()`** — a panel-builder that exposes the raw inputs
  to the trimmed-mean rate (price, nominal, quantity, weight, price
  change, trim flag) so users can replicate the rate or do component-
  level analysis.

This PR is ready to go end-to-end with no human-in-the-loop steps —
the embedded CSV is the validated mapping (177 rows after the post-2001
BEA merge).

## File map (after this PR)

```
R/
  data-dallasTrimPCEcomponents.R   # roxygen-only data doc (NEW)
  getDallasTrimPCE.R               # NEW
data/
  dallasTrimPCEcomponents.rda      # built by data-raw script (NEW)
data-raw/
  dallasTrimPCEcomponents.R        # build script (NEW)
  dallas_trim_pce_components.csv   # source CSV (NEW)
```

No new package dependencies. `LazyData: true` in DESCRIPTION already
takes care of loading the data object.

---

## 0. What this dataset is

The Dallas Fed's trimmed-mean PCE inflation rate is computed each month
from a fixed list of narrow PCE components: durables (1–41),
nondurables (42–91), services (92–177), and a single NPISH aggregate
(178). The 2009 tech notes (Dolmas, "Trimmed Mean PCE Inflation,"
updated 2022-12-23) list 178 components; BEA later combined two of them
into a single line of Table 2.4.4U when the disaggregated series ended
in December 2001, which is why the working component count is **177**.
Atkinson, Dolmas, and Zarutskie (2026) confirm 177.

## 1. Add the data

### Source CSV — `data-raw/dallas_trim_pce_components.csv`

If
`/Users/mtkonczal/Documents/command_line_AI_projects/median_pce_inflation/dallas_components_178.csv`
exists, copy it to `data-raw/dallas_trim_pce_components.csv` and rename
columns: `SeriesCode` → `series_code`, `LineNo` → `line_no`. Otherwise,
write the embedded CSV below verbatim.

```csv
dallas_idx,name,series_code,line_no,bea_label
1,New Domestic Autos,DNDCRG,7,New domestic autos
2,New Foreign Autos,DNFCRG,8,New foreign autos
3,New Light Trucks,DNWTRG,9,New light trucks
4,Used Autos,DNPURG,13,Used autos
5,Used Light Trucks,DULTRG,14,Used light trucks
6,Tires,DTIRRG,17,Tires
7,Accessories & Parts,DAPCRG,18,Accessories and parts
8,Furniture,DFURRG,21,Furniture
9,Clock/Lamp/Lighting Fixture/Other Household Decorative Items,DCLFRG,26,"Clocks, lamps, lighting fixtures, and other household decorative items"
10,Carpets & Other Floor Coverings,DCFCRG,23,Carpets and other floor coverings
11,Window Coverings,DWCVRG,25,Window coverings
12,Major Household Appliances,DMHARG,27,Major household appliances
13,Small Electric Household Appliances,DSEARG,28,Small electric household appliances
14,Dishes and Flatware,DDFLRG,30,Dishes and flatware
15,Non-Electric Cookware & Tableware,DNCTRG,31,Nonelectric cookware and tableware
16,"Tools, Hardware & Supplies",DTHWRG,33,"Tools, hardware, and supplies"
17,Outdoor Equipment & Supplies,DOEQRG,34,Outdoor equipment and supplies
18,Televisions,DTVSRG,38,Televisions
19,Other Video Equipment,DVOERG,39,Other video equipment
20,Audio Equipment,DAEQRG,40,Audio equipment
21,Prerecorded/Blank Audio Disc/Tape/Digital Files/Download,DRTDRG,45,"Prerecorded and blank audio discs, tape, digital files and downloads"
22,"Video Cassettes & Discs, Blank & Prerecorded",DOVERG,46,"Video cassettes and discs, blank and prerecorded"
23,Photographic Equipment,DPEQRG,48,Photographic equipment
24,Personal Computers & Peripheral Equipment,DCPPRG,49,Personal computers and peripheral equipment
25,Computer Software & Accessories,DCSWRG,50,Computer software and accessories
26,Calculators/Typewriters/Other Info Processing Equipment,DOIPRG,51,"Calculators, typewriters, and other information processing equipment"
27,"Sporting Equipment, Supplies, Guns & Ammunition",DSPSRG,55,"Sporting equipment, supplies, guns, and ammunition"
28,Motorcycles,DMCYRG,57,Motorcycles
29,Bicycles & Accessories,DBCYRG,58,Bicycles and accessories
30,Pleasure Boats,DBOTRG,59,Pleasure boats
31,Pleasure Aircraft,DAIRRG,60,Pleasure aircraft
32,Other Recreational Vehicles,DOREG,61,Other recreational vehicles
33,Recreational Books,DRBKRG,63,Recreational books
34,Musical Instruments,DMUSRG,64,Musical instruments
35,Jewelry,DJWLRG,66,Jewelry
36,Watches,DWCHRG,67,Watches
37,Therapeutic Medical Equipment,DMEQRG,69,Therapeutic medical equipment
38,Corrective Eyeglasses & Contact Lenses,DECLRG,70,Corrective eyeglasses and contact lenses
39,Educational Books,DEBKRG,72,Educational books
40,Luggage & Similar Personal Items,DLUGRG,73,Luggage and similar personal items
41,Telephone & Facsimile Equipment,DTCERG,71,Telephone and facsimile equipment
42,Cereals,DCERRG,79,Cereals
43,Bakery Products,DBPRRG,80,Bakery products
44,Beef and Veal,DBVLRG,81,Beef and veal
45,Pork,DPRKRG,82,Pork
46,Other Meats,DOMTRG,83,Other meats
47,Poultry,DPLTRG,84,Poultry
48,Fish and Seafood,DFSFRG,85,Fish and seafood
49,Fresh Milk,DMLKRG,86,Fresh milk
50,Processed Dairy Products,DOPDRG,87,Processed dairy products
51,Eggs,DEGSRG,88,Eggs
52,Fats and Oils,DFOLRG,89,Fats and oils
53,Fresh Fruit,DFRURG,91,Fresh fruit
54,Fresh Vegetables,DVEGRG,92,Fresh vegetables
55,Processed Fruits & Vegetables,DPFVRG,93,Processed fruits and vegetables
56,Sugar and Sweets,DSSWRG,94,Sugar and sweets
57,"Food Products, Not Elsewhere Classified",DFNCRG,95,"Food products, not elsewhere classified"
58,"Coffee, Tea & Other Beverage Materials",DCOTRG,97,"Coffee, tea, and other beverage materials"
59,"Mineral Waters, Soft Drinks & Vegetable Juices",DMSDRG,98,"Mineral waters, soft drinks, and vegetable juices"
60,Spirits,DSPRRG,100,Spirits
61,Wine,DWINRG,101,Wine
62,Beer,DBERRG,102,Beer
63,Food Produced & Consumed on Farms,DFAFRG,104,Food produced and consumed on farms
64,Women's & Girls' Clothing,DWGCRG,107,Women's and girls' clothing
65,Men's & Boys' Clothing,DMBCRG,108,Men's and boys' clothing
66,Children's & Infants' Clothing,DCICRG,109,Children's and infants' clothing
67,Clothing Materials,DCMTRG,110,Clothing materials
68,Standard Clothing Issued to Military Personnel,DMCLRG,111,Standard clothing issued to military personnel
69,Shoes & Other Footwear,DSHORG,113,Shoes and other footwear
70,Gasoline & Other Motor Fuel,DGASRG,116,Gasoline and other motor fuel
71,Lubricants & Fluids,DLUBRG,117,Lubricants and fluids
72,Fuel Oil,DFULRG,119,Fuel oil
73,Other Fuels,DOFURG,120,Other fuels
74,Prescription Drugs,DPRDRG,122,Prescription drugs
75,Nonprescription Drugs,DNPDRG,123,Nonprescription drugs
76,Other Medical Products,DOMPRG,124,Other medical products
77,"Games, Toys & Hobbies",DGTHRG,126,"Games, toys, and hobbies"
78,Pets & Related Products,DPRPRG,127,Pets and related products
79,"Flowers, Seeds & Potted Plants",DFLSRG,128,"Flowers, seeds, and potted plants"
80,Film & Photographic Supplies,DFPSRG,129,Film and photographic supplies
81,Household Cleaning Products,DHCPRG,131,Household cleaning products
82,Household Paper Products,DHPPRG,132,Household paper products
83,Household Linens,DHLNRG,133,Household linens
84,Sewing Items,DSWGRG,134,Sewing items
85,Miscellaneous Household Products,DMHPRG,135,Miscellaneous household products
86,Hair/Dental/Shave/Miscellaneous Personal Care Prods ex Electric Products,DOPHRG,138,"Hair, dental, shaving, and miscellaneous personal care products except electrical products"
87,Cosmetic/Perfumes/Bath/Nail Preparations & Implements,DCPBRG,137,"Cosmetics, perfumes, bath, nail preparations, and implements"
88,Electric Appliances for Personal Care,DEPCRG,139,Electric appliances for personal care
89,Tobacco,DTOBRG,141,Tobacco
90,Newspapers & Periodicals,DNPSRG,143,Newspapers and periodicals
91,Stationery & Miscellaneous Printed Materials,DSMPRG,144,Stationery and miscellaneous printed materials
92,Tenant-Occupied Mobile Homes,DTMHRG,155,Tenant-occupied mobile homes
93,Tenant-Occupied Stationary Homes and Landlord Durables (combined),IA000629,156,Tenant-occupied stationary homes and landlord durables
95,Owner-Occupied Mobile Homes,DOMHRG,160,Owner-occupied mobile homes
96,Owner-Occupied Stationary Homes,DOSHRG,161,Owner-occupied stationary homes
97,Rental Value of Farm Dwellings,DFRMRG,162,Rental value of farm dwellings
98,Group Housing,DGRHRG,163,Group housing
99,Water Supply & Sewage Maintenance,DWSSRG,165,Water supply and sewage maintenance
100,Garbage & Trash Collection,DGTCRG,166,Garbage and trash collection
101,Electricity,DELCRG,168,Electricity
102,Natural Gas,DGASRG2,169,Natural gas
103,Physician Services,DPHYRG,172,Physician services
104,Dental Services,DDENRG,173,Dental services
105,Paramedical Services,DPRMRG,174,Paramedical services
106,Nonprofit Hospitals' Services to Households,DHTNRG,177,Nonprofit hospitals' services to households
107,Proprietary Hospitals,DHTPRG,178,Proprietary hospitals
108,Government Hospitals,DHTGRG,179,Government hospitals
109,Nursing Homes,DNRSRG,180,Nursing homes
110,Motor Vehicle Maintenance & Repair,DMVMRG,184,Motor vehicle maintenance and repair
111,Motor Vehicle Leasing,DMVLRG,185,Motor vehicle leasing
112,Motor Vehicle Rental,DMVRRG,186,Motor vehicle rental
113,Parking Fees & Tolls,DPRKRG,187,Parking fees and tolls
114,Railway Transportation,DRRTRG,189,Railway transportation
115,Intercity Buses,DICBRG,190,Intercity buses
116,Taxicabs,DTAXRG,204,Taxicabs and ride sharing services
117,Intercity Mass Transit,DIMTRG,205,Intracity mass transit
118,Other Road Transportation Service,DORTRG,193,Other road transportation service
119,Air Transportation,DAIRRG2,194,Air transportation
120,Water Transportation,DWTRRG,195,Water transportation
121,Membership Clubs & Participant Sports Centers,DMCSRG,209,Membership clubs and participant sports centers
122,"Amusement Parks, Campgrounds & Related Recreational Services",DAMPRG,210,"Amusement parks, campgrounds, and related recreational services"
123,Motion Picture Theaters,DMPTRG,212,Motion picture theaters
124,"Live Entertainment, ex Sports",DLIGRG,215,"Live entertainment, excluding sports"
125,Spectator Sports,DSPTRG,213,Spectator sports
126,Museums & Libraries,DMLBRG,214,Museums and libraries
127,"Audio-Video, Photographic & Info Processing Services",DAVPRG,218,"Audio-video, photographic, and information processing equipment services"
128,Casino Gambling,DCGSRG,222,Casino gambling
129,Lotteries,DLOTRG,223,Lotteries
130,Pari-Mutuel Net Receipts,DPMNRG,224,Pari-mutuel net receipts
131,Veterinary & Other Services for Pets,DVETRG,226,Veterinary and other services for pets
132,Package Tours,DPKGRG,227,Package tours
133,Maintenance & Repair of Recreational Vehicles & Sports Equipment,DRMRRG,228,Maintenance and repair of recreational vehicles and sports equipment
134,Elementary & Secondary School Lunches,DESLRG,232,Elementary and secondary school lunches
135,Higher Education School Lunches,DHESRG,233,Higher education school lunches
136,Other Purchased Meals,DOPMRG,234,Other purchased meals
137,Alcohol in Purchased Meals,DAPMRG,235,Alcohol in purchased meals
138,Food Supplied to Civilians,DFSCRG,236,"Food supplied to civilians, except food produced and consumed on farms"
139,Food Supplied to Military,DFSMRG,237,Food supplied to military
140,Hotels and Motels,DHOMRG,239,Hotels and motels
141,Housing at Schools,DSCHRG,240,Housing at schools
142,Commercial Banks,DCMBRG,243,Commercial banks
143,Other Depository Institutions & Regulated Investment Companies,DODRRG,244,Other depository institutions and regulated investment companies
144,Pension Funds,DPNFRG,245,Pension funds
145,"Financial Service Charges, Fees & Commissions",DFSFRG,247,"Financial service charges, fees, and commissions"
146,Life Insurance,DLIFRG,250,Life insurance
147,Net Household Insurance,DNHIRG,251,Net household insurance
148,Net Health Insurance,DNHERG,252,Net health insurance
149,Net Motor Vehicle & Other Transportation Insurance,DNMVRG,253,Net motor vehicle and other transportation insurance
150,Communication,DCMNRG,257,Communication
151,Proprietary & Public Higher Education,DPHERG,263,Proprietary and public higher education
152,Nonprofit Private Higher Education Services to Households,DNHHRG,264,Nonprofit private higher education services to households
153,Elementary & Secondary Schools,DELSRG,265,Elementary and secondary schools
154,Day Care & Nursery Schools,DDCNRG,266,Day care and nursery schools
155,Commercial & Vocational Schools,DCMVRG,267,Commercial and vocational schools
156,Legal Services,DLGLRG,269,Legal services
157,Tax Preparation & Other Related Services,DTPSRG,270,Tax preparation and other related services
158,Employment Agency Services,DEPARG,272,Employment agency services
159,Other Personal Business Services,DOPBRG,277,Other personal business services
160,Labor Organization Dues,DLODRG,279,Labor organization dues
161,Professional Association Dues,DPADRG,280,Professional association dues
162,Funeral & Burial Services,DFUNRG,283,Funeral and burial services
163,Hairdressing Salons & Personal Grooming Establishments,DHDPRG,284,Hairdressing salons and personal grooming establishments
164,Miscellaneous Personal Care Services,DMPCRG,285,Miscellaneous personal care services
165,Laundry & Dry Cleaning Services,DDRYRG,312,Laundry and dry cleaning services
166,"Clothing Repair, Rental & Alterations",DCRRRG,287,"Clothing repair, rental, and alterations"
167,Repair & Hire of Footwear,DRHFRG,288,Repair and hire of footwear
168,Child Care,DCHCRG,290,Child care
169,Social Assistance,DSCARG,291,Social assistance
170,Social Advocacy & Civic & Social Organizations,DSACRG,294,Social advocacy and civic and social organizations
171,Religious Organizations' Services to Households,DRELRG,295,Religious organizations' services to households
172,Sales Receipts: Foundations/Grant Making/Giving Services to Household,DGIVRG,326,"Foundations, grantmaking, and giving services to households"
173,Domestic Services,DDOMRG,300,Domestic services
174,"Moving, Storage & Freight Services",DMVSRG,301,"Moving, storage, and freight services"
175,"Repair of Furniture, Furnishings & Floor Coverings",DRFFRG,302,"Repair of furniture, furnishings, and floor coverings"
176,Repair of Household Appliances,DRHARG,303,Repair of household appliances
177,Other Household Services,DOHSRG,305,Other household services
178,Final Consumption Expenditures of Nonprofit Institutions Serving Households,DNPSRG2,308,Final consumption expenditures of nonprofit institutions serving households (NPISHs)
```

> The build script that originally produced this CSV — including 15
> manual overrides for components whose names BEA writes differently
> from the Dallas tech notes — lives at
> `/Users/mtkonczal/Documents/command_line_AI_projects/median_pce_inflation/_build_178.R`.
> Re-run that script if BEA renames or restructures Table 2.4.4U again.

### Build script — `data-raw/dallasTrimPCEcomponents.R`

```r
library(readr)
library(dplyr)

dallasTrimPCEcomponents <- read_csv(
  "data-raw/dallas_trim_pce_components.csv",
  col_types = cols(
    dallas_idx  = col_integer(),
    name        = col_character(),
    series_code = col_character(),
    line_no     = col_integer(),
    bea_label   = col_character()
  )
) |> arrange(dallas_idx)

stopifnot(
  nrow(dallasTrimPCEcomponents) == 177,
  !any(is.na(dallasTrimPCEcomponents$series_code)),
  !any(is.na(dallasTrimPCEcomponents$line_no)),
  !any(duplicated(dallasTrimPCEcomponents$line_no)),
  93L %in% dallasTrimPCEcomponents$dallas_idx,
  !(94L %in% dallasTrimPCEcomponents$dallas_idx)
)

usethis::use_data(dallasTrimPCEcomponents, overwrite = TRUE)
```

Run once: `Rscript data-raw/dallasTrimPCEcomponents.R`.

### Doc — `R/data-dallasTrimPCEcomponents.R`

Mirror the style of the existing `R/data-cesDiffusionIndex.R`. Roxygen
content:

```r
#' Dallas Fed Trimmed-Mean PCE component dictionary
#'
#' A tibble mapping each of the 177 components used in the Federal Reserve
#' Bank of Dallas's trimmed-mean PCE inflation rate to its corresponding
#' series in BEA NIPA Table 2.4.4U (Fisher price index for personal
#' consumption expenditures by type of product, monthly).
#'
#' Components are organized as durables (1-41), nondurables (42-91),
#' services (92-177), and one NPISH aggregate (178). The 2009 tech notes
#' (Dolmas, "Trimmed Mean PCE Inflation," updated 2022-12-23) list 178
#' components; BEA combined two of them — Tenant-Occupied Stationary
#' Homes and Tenant Landlord Durables — into a single line of Table
#' 2.4.4U (`IA000629`) when the disaggregated series stopped in December
#' 2001. The mapping reflects that combination, yielding 177 rows;
#' `dallas_idx` runs 1..178 with 94 omitted (93 holds the merged item).
#'
#' @format A tibble with 177 rows and 5 variables:
#' \describe{
#'   \item{dallas_idx}{Integer. Ordinal position in the Dallas Fed tech-notes list.}
#'   \item{name}{Character. Component name as published by the Dallas Fed.}
#'   \item{series_code}{Character. BEA NIPA series code in Table 2.4.4U.}
#'   \item{line_no}{Integer. Line number in BEA Table 2.4.4U.}
#'   \item{bea_label}{Character. Label BEA publishes alongside `series_code`.}
#' }
#'
#' @source
#' Dolmas, J. (2009, updated 2022-12-23). "PCE Inflation: Technical
#' Note." Federal Reserve Bank of Dallas. BEA NIPA Table 2.4.4U.
#'
#' @references
#' Atkinson, T., Dolmas, J., & Zarutskie, R. (2026). "Skewness warrants
#' caution as Trimmed Mean PCE inflation eases." Federal Reserve Bank of
#' Dallas, April 16, 2026.
#'
#' @examples
#' data(dallasTrimPCEcomponents)
#' head(dallasTrimPCEcomponents)
#'
"dallasTrimPCEcomponents"
```

## 2. Add the function — `R/getDallasTrimPCE.R`

The full file is at
`/Users/mtkonczal/Documents/command_line_AI_projects/median_pce_inflation/getDallasTrimPCE.R`.
Copy it verbatim into `R/`. It depends only on `getNIPAFiles()` (already
in the package) and on `dallasTrimPCEcomponents` (added in §1).

Public signature:

```r
getDallasTrimPCE(frequency = "M", NIPA_data = NULL,
                 alpha = 0.24, beta = 0.31, components = NULL)
```

Returns a long tibble with one row per (date, component) and columns
`date, dallas_idx, name, series_code, line_no, price, nominal,
quantity, price_change, weight, is_trimmed, trim_side`. See the roxygen
in the file for full details.

---

## Validation

After all files have been added and the build script has run
(producing `data/dallasTrimPCEcomponents.rda`), run this in an R
session at the package root:

```r
devtools::document()
devtools::load_all()

# Schema & coverage
data(dallasTrimPCEcomponents)
stopifnot(
  inherits(dallasTrimPCEcomponents, "tbl_df"),
  nrow(dallasTrimPCEcomponents) == 177,
  identical(names(dallasTrimPCEcomponents),
            c("dallas_idx","name","series_code","line_no","bea_label")),
  93L %in% dallasTrimPCEcomponents$dallas_idx,
  !(94L %in% dallasTrimPCEcomponents$dallas_idx),
  !any(duplicated(dallasTrimPCEcomponents$line_no))
)

# Live join against BEA — every series_code/line_no must resolve in U20404
nipa <- getNIPAFiles(type = "M")
joined_pce <- dplyr::filter(nipa, TableId == "U20404") |>
  dplyr::distinct(SeriesCode, LineNo) |>
  dplyr::inner_join(dallasTrimPCEcomponents,
                    by = c("SeriesCode" = "series_code",
                           "LineNo"     = "line_no"))
stopifnot(nrow(joined_pce) == 177)

# Function output shape and full-coverage guarantee
panel_pce <- getDallasTrimPCE(NIPA_data = nipa)
stopifnot(
  inherits(panel_pce, "tbl_df"),
  all(c("date","dallas_idx","name","series_code","line_no","price",
        "nominal","quantity","price_change","weight",
        "is_trimmed","trim_side") %in% names(panel_pce)),
  panel_pce |>
    dplyr::filter(date == max(date), !is.na(weight)) |>
    nrow() == 177
)
cat("Dallas PCE: OK\n")

# Package check
devtools::check()
```

If any `stopifnot` fails, do not commit — surface the failure and stop.

---

## Things to watch for / non-obvious bits

- **Do not alphabetize the dictionary.** `dallas_idx` is meaningful
  (durables / nondurables / services ranges drive category
  classification in downstream code).
- **Disambiguate by line/series.** In BEA Table 2.4.4U, `DGASRG` is
  used for both *Gasoline & Other Motor Fuel* and *Natural Gas*. The
  Dallas mapping disambiguates by line number — joins against a fresh
  NIPA pull should be on `(series_code, line_no)`, not `series_code`
  alone.
- **`bea_label` is informational only.** Joins should be on
  `(series_code, line_no)`, not labels — BEA edits labels without
  renumbering.
- **Weights are computed inside the function.** `getDallasTrimPCE()`
  builds Fisher (t-1, t) weights from the data each month; nothing
  needs to be shipped with the dictionary.
- **Don't ship the rate-level helper in this PR.** Computing the
  published 12-month trimmed-mean PCE rate (with fractional boundary
  handling and Jan-2009 normalization) is a separate, larger change.
  This PR is the panel-builder + dictionary only — users can build
  whichever rate they want from the panel.
- **`download_pce.R` in the median_pce_inflation project** is not
  part of this PR. It lives with the user's analysis code, not the
  package.

---

## Commit message

```
Add dallasTrimPCEcomponents dataset and getDallasTrimPCE() panel-builder

  - dallasTrimPCEcomponents: 177-component dictionary mapping the
    Dallas Fed tech-notes list to BEA NIPA Table 2.4.4U series codes
    and line numbers (with the post-2001 BEA merge of Tenant-Occupied
    Stationary Homes + Tenant Landlord Durables).
  - getDallasTrimPCE(): long panel with price, nominal, quantity,
    Fisher weight, monthly price change, trim flag, and tail label —
    enough to replicate the rate or do component-level analysis.
```
