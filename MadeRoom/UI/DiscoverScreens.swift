import UIKit
extension ScreenViewController {
    func buildDiscover() {
        switch screen.id {
        case "D01":
            toolbar("Made Room",back:false,trailing:"bell",action:"P03")
            if let header=body.arrangedSubviews.last as? UIStackView,let title=header.arrangedSubviews.first as? UILabel {title.font = UIFontMetrics(forTextStyle:.title1).scaledFont(for:.systemFont(ofSize:28,weight:.bold));body.setCustomSpacing(0,after:header)}
            add(RoomUI.label("Craft. Home. People. A more you.",size:13,color:.secondaryLabel))
            if let subtitle=body.arrangedSubviews.last {body.setCustomSpacing(4,after:subtitle)}
            _=photo("room-hero",ratio:0.57)
            heading("Make room for you.")
            let search=action("Search ideas, projects, people…","D02",icon:"magnifyingglass");search.contentHorizontalAlignment = .leading;search.backgroundColor = UIColor(white:0.94,alpha:1);search.layer.cornerRadius=22;search.configuration?.baseForegroundColor = .secondaryLabel;search.configuration?.cornerStyle = .capsule;add(search)
            let categories=RoomUI.stack(axis:.horizontal,spacing:12);categories.distribution = .fillEqually
            for (name,asset,color,dest) in [("Pottery","pottery",UIColor(red:0.83,green:0.89,blue:0.80,alpha:1),"D03"),("Weaving","weaving",UIColor(red:0.96,green:0.86,blue:0.61,alpha:1),"D04"),("Small spaces","plant",UIColor(red:0.82,green:0.87,blue:0.94,alpha:1),"D03")] {
                let image=RoomUI.image(asset,ratio:1,radius:12);let button=action(name,dest);button.configuration?.contentInsets = .init(top:4,leading:2,bottom:6,trailing:2);button.configuration?.baseForegroundColor = .label
                let card=RoomUI.card(RoomUI.stack([image,button],spacing:0),inset:5);card.backgroundColor=color;categories.addArrangedSubview(card)
            }
            let library = RoomUI.button("Craft Library") { [weak self] in
                guard let self else { return }
                let library = KnowledgeLibraryController()
                library.openComments = { [weak self] item in
                    guard let self, let screen = self.coordinator.catalog["C04"] else { return }
                    let comments = ScreenViewController(screen: screen, coordinator: self.coordinator)
                    comments.commentKnowledgeID = item.id; comments.commentKnowledgeTitle = item.title
                    self.navigationController?.pushViewController(comments, animated: true)
                }
                self.navigationController?.pushViewController(library, animated: true)
            }
            add(library)
            add(categories);add(sectionTitle("Featured this week",destination:"D03"))
            add(artworkCard("space-reading",title:"A softer reading corner",subtitle:"Cozy textures. Natural materials. Made by you.",code:"D03"))
            add(sectionTitle("From our community",destination:"C01"))
            add(artworkCard("reading-room",title:"My woven reading corner",subtitle:"Maya · A little softer, one knot at a time.",code:"C03"))
        case "D02":
            buildSearchDesign()
        case "D03":
            toolbar("Collection",trailing:"bookmark",action:"@save");_=photo("space-reading",ratio:0.8)
            heading("A softer reading corner",subtitle:"Cozy textures, natural materials and handmade details to help you slow down and feel at home.")
            add(action("Save collection","@save",primary:true,icon:"bookmark"));add(RoomUI.label("Projects in this collection",size:20,weight:.bold))
            add(artworkCard("weave",title:"Woven wall hanging",subtitle:"Beginner · 90 min",code:"D04"))
            add(artworkCard("pottery",title:"Clay catchall",subtitle:"A small piece, a calmer day.",code:"D04"))
        default:
            toolbar("",trailing:"ellipsis",action:"@share");_=photo("weave",ratio:0.80)
            heading("Woven wall hanging",subtitle:"A modern texture for any space.")
            let badges=RoomUI.stack(axis:.horizontal,spacing:8);badges.distribution = .fillEqually
            for (text,icon) in [("Beginner","leaf"),("90 min","clock"),("6 steps","square.grid.2x2")] {let b=RoomUI.button(text,icon:icon){};b.isUserInteractionEnabled=false;b.backgroundColor = .secondarySystemGroupedBackground;b.layer.cornerRadius=12;badges.addArrangedSubview(b)}
            add(badges);segments(["Overview","Materials","Steps","Tips"],selected:segment){[weak self]_ in self?.refresh()}
            switch segment {
            case 1: materials()
            case 2: for (i,title) in Self.steps.enumerated(){add(RoomUI.label("\(i+1). \(title)",size:16))}
            case 3: add(RoomUI.label("Keep each knot loose enough to adjust. Check the row before tightening, then trim the fringe after hanging.",size:15,color:.secondaryLabel))
            default:
                add(RoomUI.label("Create a modern woven wall hanging with simple techniques and natural materials. A relaxing project that brings warmth and texture to your home.",size:15,color:.secondaryLabel))
                let avatar=RoomUI.image("studio",ratio:1,radius:32);avatar.widthAnchor.constraint(equalToConstant:64).isActive=true
                let maker=RoomUI.stack([avatar,RoomUI.stack([RoomUI.label("Made Room Studio",size:17,weight:.semibold),RoomUI.label("Home crafts for a calmer, brighter you.",size:13,color:.secondaryLabel)],spacing:5)],axis:.horizontal);maker.alignment = .center;add(maker);materials()
            }
            let buttons=RoomUI.stack([action("Save","@save",icon:"bookmark"),action("Start project →","M02",primary:true)],axis:.horizontal);buttons.distribution = .fillProportionally;add(buttons)
        }
    }
    func sectionTitle(_ title:String,destination:String)->UIView {let more=action("See all",destination);more.configuration?.contentInsets = .zero;more.titleLabel?.font = .systemFont(ofSize:13);more.titleLabel?.numberOfLines=1;more.widthAnchor.constraint(equalToConstant:70).isActive=true;let row=RoomUI.stack([RoomUI.label(title,size:19,weight:.bold),more],axis:.horizontal);row.alignment = .center;return row}
    func materials() {
        add(RoomUI.label("Materials",size:20,weight:.bold));let row=RoomUI.stack(axis:.horizontal,spacing:9);row.distribution = .fillEqually
        for (asset,name) in [("cotton","Cotton rope"),("yarn","Wool yarn"),("dowel","Wooden dowel"),("scissors","Scissors")] {row.addArrangedSubview(RoomUI.stack([RoomUI.image(asset,ratio:1,radius:10),RoomUI.label(name,size:11)],spacing:6))};add(row)
    }
}
