# Project Deliverables — Documentation Set

The documentation of the B2B Data Engineering Platform: 9 Word documents and 3 Excel workbooks,
produced from the **Project Requirements Document** given by DataRopes, which serves as the BRD.

## The documents

The numbers are the document IDs from the template set (B2B-DEP-01 … 09). They identify a document;
they are not the order in which a project writes them (see the next section).

| ID | File | What it answers |
|----|------|-----------------|
| 01 | `01_ISD_Interface_Specification.docx` | How does each source hand its data to the platform? |
| 02 | `02_Source_System_Analysis_ERD.docx` | What data do the sources contain, and can we trust it? |
| 03 | `03_LDM_Logical_Data_Model.docx` | What do we store, in business terms? |
| 04 | `04_PDM_Physical_Data_Model.docx` | How is the model built in PostgreSQL? |
| 04b | `04b_Data_Dictionary.xlsx` | What does each column mean, and which mapping loads it? |
| 05 | `05_SMX_Source_to_Target_Mapping.xlsx` | Where does every target column come from, and which rule changes it? |
| 05 | `05_SMD_Source_Mapping_Document.docx` | Why are the mappings built the way they are? |
| 06 | `06_Architecture_Document.docx` | How does the system fit together, and why this design? |
| 07 | `07_Development_Document.docx` | How was it built, and how do I run or change it? |
| 08 | `08_Test_Document.docx` | How do we know it is correct? |
| 08b | `08b_Test_Case_Register.xlsx` | Every test with its expected and actual result (161 unit · 10 integration · 15 KPI) |
| 09 | `09_KPI_Definition_Document.docx` | What exactly does each dashboard number mean? |

## Order of creation

```text
BRD (given) → 02 Source analysis → 01 Interface spec → 03 Logical model → 04 Physical model + 04b Dictionary
            → 05 SMX + SMD mapping → 06 Architecture → 07 Development → 08 Tests + 08b Register → 09 KPI definitions
```

## Tracing a KPI back to the requirement

Each document gives the identifier the next one is organised by — for example KPI-11:

```text
Dashboard (badge KPI-11) → 09 card 3.11 (fact_leads, conversion_status) → 03 / 04 (table, grain)
→ 04b Columns (Map ID M-0350) → 05 SMX (rule R19, marketing_leads.csv) → 01 ISD (IF-02) → 02 SSA (BR-8)
→ BRD: KPI-n is the n-th KPI in "Success Metrics", same name
Proof: 08b KPI_Validation, KV-11 (view 6,044 = independent count 6,044)
```

## Supporting files

| What | Where |
|------|-------|
| Diagrams (editable, draw.io) | `docs/diagrams/*.drawio` — open in draw.io Desktop, export PNG to `docs/images/` |
| Diagram images used in the documents | `docs/images/01-…08-*.png` |
| Dashboard pages (labelled with KPI numbers) | `docs/images/*.jpg` |
| Evidence screenshots (S1–S14, S16–S17) | `docs/images/screenshots/` — used as figures in documents 01–09 |
| Original plan (rules, phases) | [`project_plan.md`](project_plan.md) |
| Technical deep-dive | [`project_document.md`](project_document.md) |

## Editing the Word documents

- Figures and tables have numbered captions; the Contents, List of Figures and List of Tables are
  Word fields. After adding or moving a figure or table: **Ctrl + A, then F9** to renumber and rebuild them.
- Each document's version history is in Document Control (page 2); add a row for every change.
