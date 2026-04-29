import Foundation

// MARK: - Pace Engine

struct PaceEngine {
    let goalMinutes: Int

    var MP: Int { (goalMinutes * 60) / 26 }

    var easy            : (low: Int, high: Int) { (MP + 90,  MP + 120) }
    var longRun         : (low: Int, high: Int) { (MP + 60,  MP + 90)  }
    var generalAero     : (low: Int, high: Int) { (MP + 45,  MP + 75)  }
    var recovery        : Int                   { MP + 150 }
    var pfitzLT         : Int                   { MP - 20  }
    var hansonsStrength : (low: Int, high: Int) { (MP - 5,  MP + 5)    }
    var hansonsSpeed    : Int                   { MP - 55  }
    var dThreshold      : Int                   { MP - 28  }
    var dInterval       : Int                   { MP - 55  }
    var dRepetition     : Int                   { MP - 80  }
    var higdonTempo     : Int                   { MP - 15  }

    static func format(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
    func rangeString(_ r: (low: Int, high: Int)) -> String {
        "\(PaceEngine.format(r.high))–\(PaceEngine.format(r.low))/mi"
    }
    func singleString(_ s: Int) -> String {
        "\(PaceEngine.format(s))/mi"
    }
}
