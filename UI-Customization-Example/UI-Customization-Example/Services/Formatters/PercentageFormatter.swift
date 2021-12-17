//
// Copyright © 2018-Present. Kaleyra S.p.a. All rights reserved.
//

import Bandyer

//This formatter will print first name and last name preceded by a percentage.
class PercentageFormatter: MyFormatter {

    override func string(for obj: Any?) -> String? {
        let symbol = "%"
        if let items = obj as? [UserDetails] {
            return string(for: items, eachItemPrecededBy: symbol)
        }
        if let item = obj as? UserDetails {
            return string(for: item, precededBy: symbol)
        }

        return nil
    }
}
