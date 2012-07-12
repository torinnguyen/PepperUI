PepperUI for iOS

The files
===========================
* Pepper folder
  This is the full source code & graphics of the library, you only need to copy this to your own projects.
  You are free to modify any part of the source code to suit your needs.

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
  If you have purchased the Application License  (as oppose to more expensive Developer License)
  and need to redistribute your source code as part of a larger project, you will need to redistribute
  only the static library files, not the full source code.



Where to start?
===========================

Just run the demo project & explore the source code.



Basic setup
===========================

Project must be using ARC
Minimum XCode 4.3 & iOS SDK 5.0
1. Add Pepper folder into your project
2. Add QuartzCore Framework
3. Import PPPepperViewController.h header file into your view controller
4. Add a few lines of code in viewDidLoad or later
              PPPepperViewController *pepperVC = [[PPPepperViewController alloc] init]; 
              pepperVC.view.frame = self.view.bounds;
              [self.view addSubview:pepperVC.view];
              [pepperVC reload];
5. That's it. You will get Pepper UI with dummy content to get started with.

For the full setup & customization, please refer to the demo project or online documentation.



Documentation
===========================
Please visit http://torinnguyen.com/components/PepperUI



Final notes
===========================
New features are being developed to make this component better, more polished. You are entitled to the updates for free.
Depends on where you have purchased this component, you might get the update 1 or 2 days late, instead of immediately.


