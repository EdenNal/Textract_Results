## Examples of Challenges and Successes

`cdi_ca_1956_wk_prov_dbs.png` contains a page of data at 600 pixels per square inch. The other `png` files in this directory contain cropped portions of this file, each at the same resolution.

### `cdi_ca_1956_wk_prov_dbs-two-cols-no-header.png`

It is very easy for us to get ChatGPT to perfectly reproduce these data, using this prompt for example.

> convert the attached image with a data table into text


### `cdi_ca_1956_wk_prov_dbs-just-nfld.png`

ChatGPT can accurately recognize the characters in this file, but reproducing the layout precisely is much more difficult. A particularly challenging aspect is the repeated rows made up entirely of dashes -- while ChatGPT reads them correctly, it often fails to preserve the correct number of such rows in the output. We have not been able to prompt it to not make this mistake.


### `cdi_ca_1956_wk_prov_dbs-just-table.png`

Again, ChatGPT can accurately recognize characters but makes numerous unacceptable mistakes with the layout. We have tried many prompts to get it to understand the layout, including detailed prompts that describe the structure of the data.
