import UIKit
extension ScreenViewController {
    func buildStates() {
        switch screen.id {
        case "A01":
            toolbar("Made Room",back:false);_=photo("room-hero",ratio:0.65);heading("A home with your hand in it.",subtitle:"A creative community for a more personal, more joyful home.");add(action("Continue with Apple","@login",primary:true,icon:"apple.logo"));add(action("Continue with email","A02"));add(action("Explore first","D01"));add(action("Terms & Privacy","@terms"))
        case "A02":
            toolbar("Made Room");heading("Sign in with your email",subtitle:"Sign in to access your account.");field("Email",key:"email",placeholder:"you@example.com");fields["email"]?.keyboardType = .emailAddress;fields["email"]?.autocapitalizationType = .none;add(action("Send sign-in link","@login",primary:true));add(action("Explore first","D01"))
        case "A03":
            toolbar("Your interests");heading("What do you love most?",subtitle:"Choose a few interests to personalize your experience.");for name in ["Pottery","Weaving","Woodcraft","Small spaces","Room styling"]{toggle(name,key:"interest.\(name)")};add(action("Continue","D01",primary:true))
        case "X01":
            toolbar(coordinator.reportIsAppeal ? "Review request" : "Report content");heading("Help keep this space kind.");segments(["Spam","Harassment","Other"]);editor("Add details",key:"report");add(action("Submit report","@report",primary:true));add(action("Block maker","@block"))
        case "X02":
            buildMakeEmpty()
        case "X03":stateMessage("You're offline.",body:"Your local projects and saved content are still available.",symbol:"wifi.slash",button:"Browse local content",code:"D01")
        case "X04":stateMessage("Choose your photos",body:"Use the system photo picker to select only the photos you want to share.",symbol:"photo",button:"Choose photos",code:"@photo");add(action("Open Settings","@settings"));add(action("Not now","@back"))
        case "X05":stateMessage("Your draft is safe.",body:"Your draft is saved. Check your connection and try publishing again.",symbol:"doc.text",button:"Keep editing",code:"C02");add(action("Retry publish","@publish"))
        case "X06":toolbar("Create a project");field("Project name",key:"name",placeholder:"e.g. Cozy reading pillow");add(RoomUI.label("Give your project a name.",size:13,color:.systemRed));editor("Your process",key:"body");add(action("Create project","@createProject",primary:true))
        case "X07":stateMessage("My posts",body:"Open your online posts to check their publication and visibility.",symbol:"doc.text",button:"My posts",code:"@myPosts")
        case "X08":stateMessage("This post is no longer available.",body:"It may have been removed or may no longer be visible.",symbol:"doc.questionmark",button:"Back to community",code:"C01")
        case "X09":
            toolbar("My requests");heading("My requests",subtitle:"Track reports and review requests submitted online.")
            if let status=coordinator.actions?.status, !status.isEmpty { add(RoomUI.label(status,size:14,color:.secondaryLabel)) }
            let requests=coordinator.actions?.reports ?? []
            if requests.isEmpty { add(RoomUI.label("No requests yet.",size:16,color:.secondaryLabel)) }
            for request in requests {
                add(RoomUI.card(RoomUI.stack([RoomUI.label(request["kind"] as? String == "appeal" ? "Review request" : "Report content",size:17,weight:.semibold),RoomUI.label(AppLanguage.text(request["status"] as? String ?? "submitted"),size:14,color:.secondaryLabel),RoomUI.label(request["details"] as? String ?? "",size:14)])))
            }
            add(action("Retry","@actionsRetry"))
        case "X10":stateMessage("Account sync",body:coordinator.librarySync?.status ?? "Connecting…",symbol:"icloud",button:"Retry sync",code:"@syncRetry")
        case "X11":stateMessage("Delete this project?",body:"This deletes the project and its notes from your account after syncing. The action cannot be undone.",symbol:"trash",button:"Delete project",code:"@deleteProject");add(action("Cancel","@back"))
        case "X12":toolbar("Search");field("Search",key:"query",placeholder:"Try weaving, pottery or a room idea");heading("No ideas found yet.",subtitle:"Try different keywords or explore a related topic.");add(action("Clear filters","D02"));add(action("Browse tutorials","D04",primary:true))
        default:stateMessage("Your challenge make",body:AppLanguage.text(coordinator.actions?.challengeSubmission?["status"] as? String ?? "No submission yet."),symbol:"sparkles",button:"View submission",code:"C11")
        }
    }
    func stateMessage(_ title:String,body copy:String,symbol:String,button:String,code:String) {
        toolbar(screen.name);let icon=UIImageView(image:UIImage(systemName:symbol,withConfiguration:UIImage.SymbolConfiguration(pointSize:54,weight:.light)));icon.tintColor = .roomGreen;icon.contentMode = .scaleAspectFit;icon.heightAnchor.constraint(equalToConstant:110).isActive=true;add(icon);heading(title,subtitle:copy);add(action(button,code,primary:true))
    }
}
