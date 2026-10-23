## 0.1.5

ENHANCEMENTS:

* `serviceomat_compatible_iam_names` (default false) names extended IAM roles/instance profiles the way serviceomat did, so consumers migrating off serviceomat keep their roles
* `extended_profiles_use_extended_role` (default false) attaches the extended role to the extended instance profile
* Services accept `lb_deregistration_delay` (default 300, serviceomat's default)
* Services and tasks accept `ami_environment` to override the environment used in the default AMI name regex

## 0.1.4

ENHANCEMENTS:

* Allow aws provider 6.x
* Update to serviceomat 0.5.6

## 0.1.3

ENHANCEMENTS:

* Update to serviceomat 0.5.4
* Output created log groups

BUG FIXES:

* Respects automatic_build.build_from_account

## 0.1.2

ENHANCEMENTS:

* Attempts to select a default AMI for the service based on the account/component environment and app name.

## 0.1.1

ENHANCEMENTS:

* Creates an extended IAM role with custom tags for services and tasks which use custom tags.

## 0.1.0

* Initial release.
