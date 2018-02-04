//
//  EditBookViewController.swift
//  books
//
//  Created by Andrew Bennet on 28/04/2016.
//  Copyright © 2016 Andrew Bennet. All rights reserved.
//

import Eureka
import UIKit
import ImageRow

class BookMetadataForm: FormViewController {
    
    private let isbnKey = "isbn"
    private let titleKey = "title"
    private let authorsSectionKey = "authors"
    private let pageCountKey = "pageCount"
    private let subjectsKey = "subjects"
    private let publishedDateKey = "publishedDate"
    private let descriptionKey = "description"
    private let imageKey = "image"
    private let deleteKey = "delete"
    private let updateKey = "update"
    private let editAuthorSegueName = "editAuthorSegue"
    
    var authors = [(firstNames: String?, lastName: String)]()
    
    func configureAuthorCellsFromArray() {
        let maxIndex = max(authorsSection.count, authors.count) - 1
        for index in 0...maxIndex {
            let authorRow: AuthorButtonRow? = index < authorsSection.count ? authorsSection[index] as? AuthorButtonRow : nil
            let authorValue: (firstNames: String?, lastName: String)? = index < authors.count ? authors[index] : nil
        
            // If both row and array item present, update the row from the array item
            if let authorRow = authorRow, let authorValue = authorValue {
                authorRow.authorFirstNames = authorValue.firstNames
                authorRow.authorLastName = authorValue.lastName
            }
            else if authorRow != nil {
                let section = form.sectionBy(tag: authorsSectionKey)!
                section.remove(at: index)
            }
        }
    }
    
    func configureAuthorArrayFromCells() {
        authors.removeAll()
        for (_, row) in authorsSection.enumerated() {
            guard let authorRow = row as? AuthorButtonRow else { continue }
            guard let lastName = authorRow.authorLastName?.trimming().nilIfWhitespace() else { continue }
            let firstName = authorRow.authorFirstNames?.trimming().nilIfWhitespace()
            authors.append((firstName, lastName))
        }
    }
    
    var subjects = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        form +++ Section(header: "Title", footer: "")
            <<< NameRow(titleKey) {
                $0.placeholder = "Title"
                $0.add(rule: RuleRequired())
                $0.validationOptions = .validatesOnChange
            }.onRowValidationChanged{[unowned self] _,_ in
                self.validationChanged()
            }
        
        // Authors
        +++ AuthorMultivaluedSection(multivaluedOptions: [.Insert, .Delete], header: "Authors", footer: "") {
            let authorSection = $0 as! AuthorMultivaluedSection
            authorSection.tag = authorsSectionKey
            $0.addButtonProvider = { _ in
                return ButtonRow(){
                    $0.title = "Add Author"
                }.cellUpdate { cell, row in
                    cell.textLabel?.textAlignment = .left
                }
            }
            $0.multivaluedRowToInsertAt = { _ in
                return AuthorButtonRow(){
                    $0.cellStyle = .value1
                }.onCellSelection{ [unowned self] _, row in
                    self.performSegue(withIdentifier: self.editAuthorSegueName, sender: row)
                }.cellUpdate{ cell, _ in
                    cell.textLabel?.textColor = UIColor.black
                    cell.textLabel?.textAlignment = .left
                }
            }
            for authorValue in authors {
                $0 <<< AuthorButtonRow() {
                    $0.cellStyle = .value1
                    $0.authorLastName = authorValue.lastName
                    $0.authorFirstNames = authorValue.firstNames
                }.onCellSelection{ [unowned self] _, row in
                    self.performSegue(withIdentifier: self.editAuthorSegueName, sender: row)
                }
                .cellUpdate{ cell, _ in
                    cell.textLabel?.textColor = UIColor.black
                    cell.textLabel?.textAlignment = .left
                }
            }
        }
        
        // Details section
        +++ Section(header: "Additional Information", footer: "")
            <<< TextRow(isbnKey) {
                $0.title = "ISBN"
                $0.add(rule: RuleClosure<String> { rowValue in
                    if rowValue != nil && !rowValue!.isEmpty && Isbn13.tryParse(inputString: rowValue!) == nil {
                        // We allow blank ISBN fields, but not present, invalid text.
                        return ValidationError(msg: "Invalid ISBN")
                    }
                    return nil
                })
                $0.validationOptions = .validatesOnChange
                }.onRowValidationChanged{[unowned self] _,_ in
                    self.validationChanged()
            }
            <<< IntRow(pageCountKey) {
                $0.title = "Page Count"
            }
            <<< DateRow(publishedDateKey) {
                $0.title = "Publication Date"
            }
            <<< NavigationRow(title: "Subjects", segueName: "editSubjectsSegue", initialiser: { [unowned self] in
                $0.cellStyle = .value1
                $0.tag = self.subjectsKey
            }){ [unowned self] cell, _ in
                cell.detailTextLabel?.text = self.subjects.joined(separator: ", ")
            }
            <<< ImageRow(imageKey){
                $0.title = "Cover Image"
                $0.cell.height = {return 100}
            }
        
        // Description section
        +++ Section(header: "Description", footer: "")
            <<< TextAreaRow(descriptionKey){
                $0.placeholder = "Description"
            }.cellSetup{ [unowned self] cell, _ in
                cell.height = {return (self.view.frame.height / 3) - 10}
            }
        
        // Update and delete buttons
        +++ Section()
            <<< ButtonRow(updateKey){
                $0.title = "Update from Google Books"
            }
            <<< ButtonRow(deleteKey){
                $0.title = "Delete"
            }.cellSetup{ cell, row in
                cell.tintColor = UIColor.red
            }

        // Validate on load
        form.validate()
        
        // Add callbacks after form loaded
        authorsSection.onRowsAdded = { [unowned self] rows, _ in
            guard rows.count == 1 else { return }
            if let row = rows.first! as? AuthorButtonRow {
                self.performSegue(withIdentifier: self.editAuthorSegueName, sender: row)
            }
            self.validationChanged()
        }
        authorsSection.onRowsRemoved = { [unowned self] _, _ in
            self.configureAuthorArrayFromCells()
            self.validationChanged()
        }
    }
    
    var isbnField: TextRow {
        get { return form.rowBy(tag: isbnKey) as! TextRow }
    }
    
    var titleField: NameRow {
        get { return form.rowBy(tag: titleKey) as! NameRow }
    }
    
    var authorsSection: AuthorMultivaluedSection {
        get { return form.sectionBy(tag: authorsSectionKey) as! AuthorMultivaluedSection }
    }
    
    var pageCount: IntRow {
        get { return form.rowBy(tag: pageCountKey) as! IntRow }
    }
    
    var publicationDate: DateRow {
        get { return form.rowBy(tag: publishedDateKey) as! DateRow }
    }
    
    var subjectsButton: ButtonRow {
        get { return form.rowBy(tag: subjectsKey) as! ButtonRow }
    }
    
    var descriptionField: TextAreaRow {
        get { return form.rowBy(tag: descriptionKey) as! TextAreaRow }
    }
    
    var image: ImageRow {
        get { return form.rowBy(tag: imageKey) as! ImageRow }
    }
    
    var updateRow: ButtonRow {
        get { return form.rowBy(tag: updateKey) as! ButtonRow }
    }

    var deleteRow: ButtonRow {
        get { return form.rowBy(tag: deleteKey) as! ButtonRow }
    }

    private func validationChanged() {
        // A bit of custom validation because Sections cannot have validators:
        let anyAuthors = authorsSection.count > 1
        formValidated(isValid: anyAuthors && form.rows.flatMap{$0.validationErrors}.isEmpty)
    }
    
    func formValidated(isValid: Bool) {
        // Should be overriden
    }
    
    func dismiss(completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        self.navigationController?.dismiss(animated: true, completion: completion)
    }
    
    func anyData() -> Bool {
        return titleField.value != nil || !authors.isEmpty || pageCount.value != nil || !subjects.isEmpty
            || publicationDate.value != nil || descriptionField.value != nil || image.value != nil
    }
    
    func populateMetadata(_ metadata: BookMetadata) {
        metadata.title = titleField.value
        metadata.authors = authors
        metadata.pageCount = pageCount.value
        metadata.subjects = subjects
        metadata.publicationDate = publicationDate.value
        metadata.bookDescription = descriptionField.value
        
        // FUTURE: it would be nice if we didn't have to reencode to JPEG every time
        metadata.coverImage = image.value == nil ? nil : UIImageJPEGRepresentation(image.value!, 0.7)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let subjectsVc = segue.destination as? BookSubjectsForm {
            subjectsVc.subjects = subjects
        }
        if let authorsVs = segue.destination as? BookAuthorForm {
            let authorRow = sender as! AuthorButtonRow
            authorsVs.authorButton = authorRow
            authorsVs.firstNames = authorRow.authorFirstNames
            authorsVs.lastName = authorRow.authorLastName
        }
        else {
            configureAuthorArrayFromCells()
        }
    }
}

class BookAuthorForm: FormViewController {
    var authorButton: AuthorButtonRow!
    var firstNames: String?
    var lastName: String?
    
    var bookMetadataForm: BookMetadataForm {
        get { return navigationController!.viewControllers.first! as! BookMetadataForm }
    }
    
    private let firstNameTag = "firstName"
    private let lastNameTag = "lastName"
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        form +++ Section(header: "Author Name", footer: "")
            <<< NameRow(firstNameTag) {
                $0.placeholder = "First Name(s)"
                $0.value = firstNames
            }
            <<< NameRow(lastNameTag) {
                $0.placeholder = "Last Name"
                $0.value = lastName
            }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Update the name properties, and set them on the source button
        firstNames = (form.rowBy(tag: firstNameTag) as! NameRow).value?.trimming()
        lastName = (form.rowBy(tag: lastNameTag) as! NameRow).value?.trimming()
        authorButton.authorFirstNames = firstNames
        authorButton.authorLastName = lastName
        
        bookMetadataForm.configureAuthorArrayFromCells()
        bookMetadataForm.configureAuthorCellsFromArray()

        super.viewWillDisappear(animated)
    }
}

class AuthorMultivaluedSection: MultivaluedSection {
    public var onRowsAdded: (([BaseRow], IndexSet) -> Void)?
    public var onRowsRemoved: (([BaseRow], IndexSet) -> Void)?
    
    override func rowsHaveBeenAdded(_ rows: [BaseRow], at: IndexSet) {
        onRowsAdded?(rows, at)
    }
    
    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at: IndexSet) {
        onRowsRemoved?(rows, at)
    }
}

final class AuthorButtonRow: _ButtonRowOf<String>, RowType {
    required init(tag: String?) {
        super.init(tag: tag)
    }
    
    var authorLastName: String? {
        didSet {
            authorLastName = authorLastName?.trimming().nilIfWhitespace()
            configure()
        }
    }
    
    var authorFirstNames: String? {
        didSet {
            authorFirstNames = authorFirstNames?.trimming().nilIfWhitespace()
            configure()
        }
    }
    
    private func configure() {
        var authorPieces = [String]()
        if let firstName = authorFirstNames { authorPieces.append(firstName) }
        if let lastName = authorLastName { authorPieces.append(lastName) }
        title = authorPieces.joined(separator: " ")
        reload()
    }
}

class BookSubjectsForm: FormViewController {
    var subjects = [String]()
    
    var bookMetadataForm: BookMetadataForm {
        get { return navigationController!.viewControllers.first! as! BookMetadataForm }
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        form +++ MultivaluedSection(multivaluedOptions: [.Insert, .Delete, .Reorder], header: "Subjects", footer: "Add subjects to categorise this book") {
            $0.addButtonProvider = { _ in
                return ButtonRow(){
                    $0.title = "Add New Subject"
                }.cellUpdate { cell, row in
                    cell.textLabel?.textAlignment = .left
                }
            }
            $0.multivaluedRowToInsertAt = { _ in
                return NameRow() {
                    $0.placeholder = "Subject"
                }
            }
            for subject in subjects {
                $0 <<< NameRow() {
                    $0.value = subject
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        bookMetadataForm.subjects = form.rows.flatMap{($0 as? NameRow)?.value?.trimming().nilIfWhitespace()}.distinct()
        bookMetadataForm.subjectsButton.updateCell()
        super.viewWillDisappear(animated)
    }
}
