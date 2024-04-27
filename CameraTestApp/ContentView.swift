//
//  ContentView.swift
//  CameraTestApp
//
//  Created by Gokul Murugan on 19/02/24.
//

import SwiftUI

struct SelecetedItem{
    let name:String
    let decription:String = "Masala dosa is a popular South Indian dish that has gained widespread popularity across the country and beyond. It is a type of fermented crepe or pancake made from a batter of rice and urad dal (black gram)."
    let macros:Macros
}

struct Macros{
    let protein:Double
    let carbs:Double
    let fats:Double
}

enum DietaryMacros{
    case Protein, Fats, Carbs
}

struct ContentView: View {
    @StateObject var viewModel = ViewModel()
    @State var leftDisplay:Bool = false
    @State var onTapped:Bool = false
    @State var selectedItemToDisp:SelecetedItem?
    var body: some View {
        ZStack{
            HostedViewController(viewModel: viewModel)
                .ignoresSafeArea()
            VStack{
                Spacer()
                if let result = viewModel.result{
                    
                    returnListOfData(data: result)
                }
                Spacer()
                Button("Stop Session"){
                    viewModel.stopSession.toggle()
                }
                if onTapped{
                    if let selected = selectedItemToDisp{
                        returnSelection(item: selected)
                    }
                }
            }
            
            
        }
    }
}

extension ContentView{
    private func  returnListOfData(data:ImageClassificationResult) -> some View{
        VStack(spacing: 30){
            ForEach(data.classifications.categories, id: \.self){ label in
                ZStack{
                    HStack{
                        if !leftDisplay {
                            Spacer()
                                .onAppear{
                                    leftDisplay.toggle()
                                }
                        }
                        ZStack{
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundStyle(.white)
                                .frame(width: 150, height: 55)
                            HStack{
                                Image("icon")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 55, height: 45)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading){
                                    if let disp = label.label{
                                        Text(disp.capitalized)
                                            .font(.system(size: 10).weight(.semibold))
                                            .foregroundStyle(.black)
                                    } else {
                                        Text("Nil")
                                            .font(.system(size: 10).weight(.semibold))
                                    }
                                    
                                    Text("1 pc")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.gray)
                                    Text("80 cal")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.red)
                                }
                                .padding(.leading,5)
                                Spacer()
                            }.padding(.horizontal, 3)
                        }
                        .onTapGesture {
                            if !onTapped{
                                onTapped.toggle()
                            }
                            selectedItemToDisp = SelecetedItem(name: label.label!, macros: Macros(protein: 7, carbs: 0.9, fats: 2.8))
                        }
                        .frame(width: 150, height: 55)
                        
                        if leftDisplay{
                            Spacer()
                                .onAppear{
                                    leftDisplay.toggle()
                                }
                        }
                    }
                   
                }
                .frame(width: UIScreen.main.bounds.width / 1.5)
            }
        }
    }
    private func returnSelection(item:SelecetedItem) -> some View{
        ZStack{
            RoundedRectangle(cornerRadius: 12)
                .foregroundStyle(.white)
            VStack(spacing: 5){
                HStack{
                    Text(item.name.capitalized)
                        .font(.system(size: 16).weight(.semibold))
                        .foregroundStyle(.black)
                    
                    Spacer()
                    Button(action: {
                        //MARK: Add to meal
                    }, label: {
                        Text("Add to Meal >")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12).weight(.medium))
                    })
                    
                }
                Text(item.decription)
                    .font(.system(size: 10).weight(.regular))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.gray)
                HStack{
                    returnMacros(name: .Protein, quantity: item.macros.protein)
                    Spacer()
                    returnMacros(name: .Fats, quantity: item.macros.fats)
                    Spacer()
                    returnMacros(name: .Carbs, quantity: item.macros.carbs)
                }
                
            }
            .padding(.horizontal,20)
            .padding(.vertical, 10)
            
        }.frame(width: 300, height: 145)
    }
    
    private func returnMacros(name:DietaryMacros, quantity:Double) -> some View{
        VStack(alignment: .leading, spacing: 3){
            switch name{
            case .Protein:
                Text("Protein")
                    .font(.system(size: 8).weight(.bold))
                    .foregroundStyle(.green)
            case .Carbs:
                Text("Carbohydrates")
                    .font(.system(size: 8).weight(.bold))
                    .foregroundStyle(.blue)
            case .Fats:
                Text("Fats")
                    .font(.system(size: 8).weight(.bold))
                    .foregroundStyle(.red)
            }
            Text("\(quantity) gm")
                .font(.system(size: 8))
                .foregroundStyle(.gray)
        }
        
    }
}

#Preview {
    ContentView()
}
