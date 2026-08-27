/// CA province / US state options for the "Tax & Shipping Destination"
/// section of Add Part — a Dart port of the web app's `CA_PROVINCES` /
/// `US_STATES` (`src/constants/tax.constants.ts`). Keep in sync with that
/// file if the web list ever changes.
class TaxRegionOption {
  const TaxRegionOption(this.value, this.label);

  final String value;
  final String label;
}

const List<TaxRegionOption> kCaProvinces = [
  TaxRegionOption('ON', 'Ontario (ON)'),
  TaxRegionOption('QC', 'Quebec (QC)'),
  TaxRegionOption('BC', 'British Columbia (BC)'),
  TaxRegionOption('AB', 'Alberta (AB)'),
  TaxRegionOption('MB', 'Manitoba (MB)'),
  TaxRegionOption('SK', 'Saskatchewan (SK)'),
  TaxRegionOption('NS', 'Nova Scotia (NS)'),
  TaxRegionOption('NB', 'New Brunswick (NB)'),
  TaxRegionOption('PE', 'Prince Edward Island (PE)'),
  TaxRegionOption('NL', 'Newfoundland and Labrador (NL)'),
  TaxRegionOption('YT', 'Yukon (YT)'),
  TaxRegionOption('NT', 'Northwest Territories (NT)'),
  TaxRegionOption('NU', 'Nunavut (NU)'),
];

const List<TaxRegionOption> kUsStates = [
  TaxRegionOption('AL', 'Alabama (AL)'),
  TaxRegionOption('AK', 'Alaska (AK)'),
  TaxRegionOption('AZ', 'Arizona (AZ)'),
  TaxRegionOption('AR', 'Arkansas (AR)'),
  TaxRegionOption('CA', 'California (CA)'),
  TaxRegionOption('CO', 'Colorado (CO)'),
  TaxRegionOption('CT', 'Connecticut (CT)'),
  TaxRegionOption('DE', 'Delaware (DE)'),
  TaxRegionOption('FL', 'Florida (FL)'),
  TaxRegionOption('GA', 'Georgia (GA)'),
  TaxRegionOption('HI', 'Hawaii (HI)'),
  TaxRegionOption('ID', 'Idaho (ID)'),
  TaxRegionOption('IL', 'Illinois (IL)'),
  TaxRegionOption('IN', 'Indiana (IN)'),
  TaxRegionOption('IA', 'Iowa (IA)'),
  TaxRegionOption('KS', 'Kansas (KS)'),
  TaxRegionOption('KY', 'Kentucky (KY)'),
  TaxRegionOption('LA', 'Louisiana (LA)'),
  TaxRegionOption('ME', 'Maine (ME)'),
  TaxRegionOption('MD', 'Maryland (MD)'),
  TaxRegionOption('MA', 'Massachusetts (MA)'),
  TaxRegionOption('MI', 'Michigan (MI)'),
  TaxRegionOption('MN', 'Minnesota (MN)'),
  TaxRegionOption('MS', 'Mississippi (MS)'),
  TaxRegionOption('MO', 'Missouri (MO)'),
  TaxRegionOption('MT', 'Montana (MT)'),
  TaxRegionOption('NE', 'Nebraska (NE)'),
  TaxRegionOption('NV', 'Nevada (NV)'),
  TaxRegionOption('NH', 'New Hampshire (NH)'),
  TaxRegionOption('NJ', 'New Jersey (NJ)'),
  TaxRegionOption('NM', 'New Mexico (NM)'),
  TaxRegionOption('NY', 'New York (NY)'),
  TaxRegionOption('NC', 'North Carolina (NC)'),
  TaxRegionOption('ND', 'North Dakota (ND)'),
  TaxRegionOption('OH', 'Ohio (OH)'),
  TaxRegionOption('OK', 'Oklahoma (OK)'),
  TaxRegionOption('OR', 'Oregon (OR)'),
  TaxRegionOption('PA', 'Pennsylvania (PA)'),
  TaxRegionOption('RI', 'Rhode Island (RI)'),
  TaxRegionOption('SC', 'South Carolina (SC)'),
  TaxRegionOption('SD', 'South Dakota (SD)'),
  TaxRegionOption('TN', 'Tennessee (TN)'),
  TaxRegionOption('TX', 'Texas (TX)'),
  TaxRegionOption('UT', 'Utah (UT)'),
  TaxRegionOption('VT', 'Vermont (VT)'),
  TaxRegionOption('VA', 'Virginia (VA)'),
  TaxRegionOption('WA', 'Washington (WA)'),
  TaxRegionOption('WV', 'West Virginia (WV)'),
  TaxRegionOption('WI', 'Wisconsin (WI)'),
  TaxRegionOption('WY', 'Wyoming (WY)'),
];
