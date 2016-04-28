PepperUI for iOS
===========================
[![Demo video](https://img.youtube.com/vi/DtCFtMWC3VI/0.jpg)](https://www.youtube.com/watch?v= DtCFtMWC3VI)


The files
===========================
* Pepper folder
  This is the full source code & graphics of the library, you only need to copy this to your own projects.
  You are free to modify any part of the source code to suit your needs.

* PepperSimple folder
* PepperSimple.xcodeproject
  Get started with this project.
  This is a very basic demo project, containing only a few lines of codes to setup PepperUI library.
  This demo project directly reference the source code in Pepper folder above.

* PepperDemo folder
* PepperDemo.xcodeproject
  This is the demo project as seen in the screenshots & promotion video.
  This demo project directly reference the source code in Pepper folder above.

* PepperUIStatic
* PepperUIStatic.xcodeproject
  This project compiles Pepper folder into static library files (.a).
  You will need to compile once for device & once more for simulator.
  Please refer to the free-to-try project on Github for using the static library.
  https://github.com/torinnguyen/PepperUIDemoFree



Where to start?
===========================

PepperSimple project

Just run the demo project & explore the source code.



Basic setup
===========================

* Project must be using ARC
* Minimum XCode 4.3 & iOS SDK 5.0
* Add Pepper folder into your project
* Add QuartzCore Framework
* Import PPPepperViewController.h header file into your view controller
* Add a few lines of code in viewDidLoad or later
              PPPepperViewController *pepperVC = [[PPPepperViewController alloc] init]; 
              pepperVC.view.frame = self.view.bounds;
              [self.view addSubview:pepperVC.view];
              [pepperVC reload];
* That's it. You will get Pepper UI with dummy content to get started with.

For the full setup & customization, please refer to the demo project or online documentation.



Documentation
===========================
Please visit http://torinnguyen.com/components/PepperUI


License
===========================
Do what you want with it
