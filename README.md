# Reading List
[![Build Status](https://travis-ci.org/AndrewBennet/ReadingList.svg?branch=master)](https://travis-ci.org/AndrewBennet/ReadingList)
[![codebeat badge](https://codebeat.co/badges/3f7723a7-8967-436e-b5e9-549e0261603c)](https://codebeat.co/projects/github-com-andrewbennet-readinglist)

[Reading List](https://www.readinglistapp.xyz) is a free, open source iOS app for iPhone and iPad. Reading List allows users to track and catalog the books they read.

<img src="https://www.readinglistapp.xyz/assets/iPhone%20X-0_ToReadList_framed.png" width="280"></img>

<a href="https://itunes.apple.com/us/app/reading-list-book-log/id1217139955?mt=8">
  <img src="https://linkmaker.itunes.apple.com/assets/shared/badges/en-us/appstore-lrg.svg" style="height: 60px;"/>
</a>

## Requirements
 - Xcode 9.2 +
 - Swift 4 +

## Dependencies
Reading List uses [CocoaPods](https://cocoapods.org/) for including third-party libraries, and [fastlane](https://fastlane.tools/) to automate some processes. To install the correct versions, run:

    gem install bundler
    bundler install
    pod install

## Architecture
Reading List is written in Swift, and primarily uses Apple provided technologies.

### UI
Reading List mostly uses [storyboards](https://developer.apple.com/library/content/documentation/General/Conceptual/Devpedia-CocoaApp/Storyboard.html) for UI design (see below); a limited number of user input views are built using [Eureka](https://github.com/xmartlabs/Eureka) forms.

![Example storyboard](./media/storyboard.png)

### Data persistence
Reading List uses [Core Data](https://developer.apple.com/documentation/coredata) for data persistence. There are four entities used in Reading List: `Book`, `Author`, `Subject` and `List`. The attributes and relations between then are illustrated below:

![Core data entities](./media/coredata_entities.png)
