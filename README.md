<header>

<!--
  <<< Author notes: Course header >>>
  Include a 1280×640 image, course title in sentence case, and a concise description in emphasis.
  In your repository settings: enable template repository, add your 1280×640 social image, auto delete head branches.
  Add your open source license, GitHub uses MIT license.
-->

# Welcome to HeishaMon-Rules-with-Opentherm-Thermostat



The purpose of this all is to publish the rules I use on my HeishaMon to control my Panasonic Heat Pump in combination with an Opentherm thermostat.


</header>

<!--

-->

## My Requirements for the Rules Set:

1)  Max Pump Speed based on HP status 1) DHW, 2) HEAT/COOL (and the outside temp as well), IDLE flow;
2)  QuiteMode based on time (e.g. at night) & for Heat/Cool at start Compressor until Compressor Frequency < 30 Hz.;
3)  DHW production if DHWTemp <39, every day at fixed time if DHWTemp < DHWTargetTemp + DHWDelta and 1 x per week (at LegionellaRunDay) a legionellarun;
4)  WAR calcuation based on WAR Temperature settings from HP;
5)  Result of WAR calculation used for OT maxTSet (which is used by OT Thermostat as Maximum ?chSetpoint);
6)  Sync OT values with HP values to have correct (status) values from HP communicated to OT Thermostat;
7)  OT Thermostat HP control: 1) sync Main_Target_Temp with ?chSetpoint and 2) switch off HP (wapter pump) when ?chEnable is 0 (for a mimumum time);
8)  Softstart function with 1) minimize Compressor Frequency asap and 2) increase Main_Target_Temp to extend the run time.


<footer>

<!--
  <<< Author notes: Footer >>>
  Add a link to get support, GitHub status page, code of conduct, license link.
-->

---

Get help: [Post in our discussion board](https://github.com/orgs/skills/discussions/categories/github-pages) &bull; [Review the GitHub status page](https://www.githubstatus.com/)

&copy; 2023 GitHub &bull; [Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/code_of_conduct.md) &bull; [MIT License](https://gh.io/mit)

</footer>
