CREATE DATABASE IF NOT EXISTS lab1;
USE lab1;

CREATE TABLE Warehouse (
    WarehouseID INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier of a warehouse',
    WarehouseName VARCHAR(100) NOT NULL COMMENT 'Warehouse name',
    Address VARCHAR(200) NOT NULL COMMENT 'Physical address',
    City VARCHAR(100) NOT NULL COMMENT 'City where the warehouse is located',
    Country VARCHAR(100) NOT NULL COMMENT 'Country where the warehouse is located',
    CapacityM3 DECIMAL(12,2) NOT NULL CHECK (CapacityM3 >= 0) COMMENT 'Maximum storage capacity in cubic meters',
    
    CONSTRAINT pk_warehouse_id PRIMARY KEY (WarehouseID)
);
CREATE INDEX idx_warehouse_name ON Warehouse(WarehouseName) COMMENT 'Supports searching warehouses by name';

CREATE TABLE Product (
    ProductID   INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier of a product',
    ProductName VARCHAR(150) NOT NULL COMMENT 'Product name',
    Description TEXT NULL COMMENT 'Additional product details',
    Unit        VARCHAR(20) NOT NULL COMMENT 'Base unit used to measure quantity',
    ProductType VARCHAR(50) COMMENT 'Product category; allowed values are not finalized in Phase 1',
    
    CONSTRAINT pk_product_id PRIMARY KEY (ProductID)
);
CREATE INDEX idx_product_name ON Product(ProductName) COMMENT 'Supports product-name lookups';

CREATE TABLE Supplier (
    SupplierID   INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier of a supplier',
    SupplierName VARCHAR(150) NOT NULL COMMENT 'Supplier business name',
    ContactName  VARCHAR(100) COMMENT 'Main contact person',
    Phone        VARCHAR(30) COMMENT 'Supplier contact telephone number',
    Email        VARCHAR(150) COMMENT 'Supplier contact email; not unique unless the business requires it',
    Address      VARCHAR(200) COMMENT 'Supplier business address',
    
    CONSTRAINT pk_supplier_id PRIMARY KEY (SupplierID)
);
CREATE INDEX idx_supplier_name ON Supplier(SupplierName) COMMENT 'Supports supplier-name lookups';

CREATE TABLE Inventory (
    InventoryID INT NOT NULL AUTO_INCREMENT COMMENT 'Unique inventory record identifier',
    WarehouseID INT NOT NULL COMMENT 'Warehouse holding the product',
    ProductID   INT NOT NULL COMMENT 'Product held at the warehouse',
    Quantity    DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (Quantity >= 0) COMMENT 'Current stock balance',
    ReorderLevel DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (ReorderLevel >= 0) COMMENT 'Threshold below which a restock alert is opened',
    LastUpdated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last inventory record update time',
    
    CONSTRAINT pk_inventory_id PRIMARY KEY (InventoryID),
    CONSTRAINT uq_inventory_warehouseid_productid UNIQUE (WarehouseID, ProductID),
    CONSTRAINT fk_inventory_warehouse_id FOREIGN KEY (WarehouseID) REFERENCES Warehouse(WarehouseID),
    CONSTRAINT fk_inventory_product_id FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
);

CREATE TABLE SupplierProduct (
    SupplierID   INT NOT NULL COMMENT 'Supplier offering the product',
    ProductID    INT NOT NULL COMMENT 'Product offered by the supplier',
    UnitPrice    DECIMAL(12,2) NOT NULL CHECK (UnitPrice >= 0) COMMENT 'Current price offered by this supplier',
    LeadTimeDays INT NOT NULL DEFAULT 0 CHECK (LeadTimeDays >= 0) COMMENT 'Expected supplier delivery lead time in days',
    
    CONSTRAINT pk_supplierproduct_supplierid_productid PRIMARY KEY (SupplierID, ProductID),
    CONSTRAINT fk_supplierproduct_supplier_id FOREIGN KEY (SupplierID) REFERENCES Supplier(SupplierID),
    CONSTRAINT fk_supplierproduct_product_id FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
);

CREATE TABLE SupplierOrder (
    OrderID              INT NOT NULL AUTO_INCREMENT COMMENT 'Unique supplier order identifier',
    OrderDate            DATE NOT NULL COMMENT 'Date the order was created',
    ExpectedDeliveryDate DATE COMMENT 'Expected date at the destination warehouse',
    Status               VARCHAR(20) NOT NULL DEFAULT 'Draft' COMMENT 'Lifecycle status; Draft and Submitted are used by the report rules',
    SupplierID           INT NOT NULL COMMENT 'Supplier receiving the purchase order',
    WarehouseID          INT NOT NULL COMMENT 'Destination warehouse for the order',
    CONSTRAINT pk_order_id PRIMARY KEY (OrderID),
    CONSTRAINT fk_order_supllier_id FOREIGN KEY (SupplierID) REFERENCES Supplier(SupplierID),
    CONSTRAINT fk_order_warehouse_id FOREIGN KEY (WarehouseID) REFERENCES Warehouse(WarehouseID)
);
CREATE INDEX idx_order_status_date ON SupplierOrder(Status, OrderDate) COMMENT 'Supports filtering orders by status and date';

CREATE TABLE SupplierOrderItem (
    OrderItemID INT NOT NULL AUTO_INCREMENT COMMENT 'Unique order line identifier',
    OrderID     INT NOT NULL COMMENT 'Supplier order containing this line',
    ProductID   INT NOT NULL COMMENT 'Product being ordered',
    Quantity    DECIMAL(12,2) NOT NULL CHECK (Quantity > 0) COMMENT 'Quantity requested on this order line',
    UnitPrice   DECIMAL(12,2) NOT NULL CHECK (UnitPrice >= 0) COMMENT 'Historical price agreed for this order line',

    CONSTRAINT pk_orderitem_id PRIMARY KEY (OrderItemID),
    CONSTRAINT uq_orderitem_orderid_productid UNIQUE (OrderID, ProductID),
    CONSTRAINT fk_orderitem_order_id FOREIGN KEY (OrderID) REFERENCES SupplierOrder(OrderID),
    CONSTRAINT fk_orderitem_product_id FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
);

CREATE TABLE Shipment (
    ShipmentID      INT NOT NULL AUTO_INCREMENT COMMENT 'Unique shipment identifier',
    OrderID         INT NOT NULL COMMENT 'Supplier order fulfilled by this shipment',
    TrackingNumber  VARCHAR(50) COMMENT 'External carrier tracking reference',
    ShipmentDate    DATE COMMENT 'Date the shipment is dispatched',
    EstimatedArrival DATETIME COMMENT 'Current estimated arrival date and time',
    ActualArrival   DATETIME COMMENT 'Confirmed arrival date and time',
    Status          VARCHAR(20) NOT NULL DEFAULT 'Draft' COMMENT 'Shipment lifecycle status',
    
	CONSTRAINT pk_shipment_id PRIMARY KEY (ShipmentID),
    CONSTRAINT fk_shipment_order_id FOREIGN KEY (OrderID) REFERENCES SupplierOrder(OrderID)
);
CREATE INDEX idx_shipment_status ON Shipment(Status);

CREATE TABLE ShipmentItem (
    ShipmentItemID INT NOT NULL AUTO_INCREMENT COMMENT 'Unique shipment line identifier',
    ShipmentID     INT NOT NULL COMMENT 'Shipment containing this allocation',
    OrderItemID    INT NOT NULL COMMENT 'Supplier order line being delivered',
    Quantity       DECIMAL(12,2) NOT NULL CHECK (Quantity > 0) COMMENT 'Quantity allocated to this shipment',
    
    CONSTRAINT pk_shipmentitem_id PRIMARY KEY (ShipmentItemID),
    CONSTRAINT fk_shipmentitem_shipment_id FOREIGN KEY (ShipmentID) REFERENCES Shipment(ShipmentID),
    CONSTRAINT fk_shipmentitem_orderitem_id FOREIGN KEY (OrderItemID) REFERENCES SupplierOrderItem(OrderItemID)
);

CREATE TABLE TrackingEvent (
	TrackingEventID INT NOT NULL AUTO_INCREMENT COMMENT 'Unique identifier for a tracking event, including events at the same time',
    ShipmentID      INT NOT NULL COMMENT 'Shipment associated with this event',
    EventTime       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Event time',
    Location        VARCHAR(150) COMMENT 'Location where the event was recorded',
    Status          VARCHAR(30) NOT NULL COMMENT 'Status reported by the tracking event',
    Description     TEXT COMMENT 'Additional tracking or handling details',

    CONSTRAINT pk_trackingevent_id PRIMARY KEY (TrackingEventID),
    CONSTRAINT fk_trackingevent_shipment_id FOREIGN KEY (ShipmentID) REFERENCES Shipment(ShipmentID)
);
CREATE INDEX idx_tracking_shipment_time ON TrackingEvent(ShipmentID, EventTime, TrackingEventID) COMMENT 'Supports chronological tracking history per shipment';

CREATE TABLE ProductComponent (
    ParentProductID    INT NOT NULL COMMENT 'Product assembled from components',
    ComponentProductID INT NOT NULL COMMENT 'Direct component used by the parent product',
    QuantityRequired   DECIMAL(12,2) NOT NULL CHECK (QuantityRequired > 0) COMMENT 'Number of component units required for one parent unit',
    
    CONSTRAINT pk_productcomponent_id PRIMARY KEY (ParentProductID, ComponentProductID),
    CONSTRAINT ck_productcomponent CHECK (ParentProductID <> ComponentProductID),
    CONSTRAINT fk_productcomponent_parent_id FOREIGN KEY (ParentProductID) REFERENCES Product(ProductID),
    CONSTRAINT fk_productcomponent_component_id FOREIGN KEY (ComponentProductID) REFERENCES Product(ProductID)
);

CREATE TABLE StockMovement (
    MovementID     INT NOT NULL AUTO_INCREMENT COMMENT 'Unique stock transaction identifier',
    InventoryID    INT NOT NULL COMMENT 'Inventory balance affected by this movement',
    ShipmentItemID INT UNIQUE COMMENT 'Required only for Receipt movements; each shipment item can be received once',
    MovementTime   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Time the movement is recorded',
    MovementType   VARCHAR(20) NOT NULL COMMENT 'Opening, Receipt, Issue, or Adjustment',
    QuantityDelta  DECIMAL(12,2) NOT NULL COMMENT 'Signed change in inventory quantity',
    
    CONSTRAINT uq_stockmovementid_shipmentitemid UNIQUE(MovementID, ShipmentItemID),
	CONSTRAINT pk_stockmovement_id PRIMARY KEY(MovementID),
    CONSTRAINT fk_stockmovement_inventory_id FOREIGN KEY (InventoryID) REFERENCES Inventory(InventoryID),
    CONSTRAINT fk_stockmovement_shipmentitem_id FOREIGN KEY (ShipmentItemID) REFERENCES ShipmentItem(ShipmentItemID)
);
CREATE INDEX idx_movement_inventory_time ON StockMovement(InventoryID, MovementTime, MovementID) COMMENT 'Supports movement history lookup by inventory and time';

CREATE TABLE RestockAlert (
	AlertID               INT NOT NULL AUTO_INCREMENT COMMENT 'Unique low-stock alert period identifier',
    InventoryID           INT NOT NULL COMMENT 'Inventory record that triggered the alert',
    AlertDate             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Time the low-stock condition was detected',
    QuantityAtAlert       DECIMAL(12,2) NOT NULL COMMENT 'Quantity snapshot when this alert opened',
    ReorderLevelAtAlert   DECIMAL(12,2) NOT NULL COMMENT 'Reorder level snapshot when this alert opened',
    ResolvedAt            DATETIME COMMENT 'Resolution time; NULL means alert is unresolved',
    Message               VARCHAR(200) COMMENT 'Human-readable alert explanation',
    
    CONSTRAINT pk_restockalert_id PRIMARY KEY(AlertID),
	CONSTRAINT ck_restockalert CHECK (QuantityAtAlert < ReorderLevelAtAlert),
    CONSTRAINT fk_restockalert_inventory_id FOREIGN KEY (InventoryID) REFERENCES Inventory(InventoryID)
);
CREATE INDEX idx_alert_inventory_date ON RestockAlert(InventoryID, AlertDate) COMMENT 'Supports alert-history lookup for an inventory record';